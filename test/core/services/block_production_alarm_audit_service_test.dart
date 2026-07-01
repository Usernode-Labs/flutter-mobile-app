import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/metrics/mobile_context_snapshot_collector.dart';
import 'package:crypto_mobile_app/src/rust/observability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockProductionAlarmAuditService', () {
    test('skips when exact alarm permission is missing', () async {
      final harness = _AuditHarness(exactAlarmPermission: false);

      final result = await harness.service.audit(reason: 'cold_start');

      expect(result.skippedReason, 'no_exact_alarm_permission');
      expect(harness.ensureNodeRunningCalls, 0);
      expect(harness.foregroundResumeSchedules, isEmpty);
      expect(
        harness.events('fg_resume_watchdog_skipped').single['skipped_reason'],
        'no_exact_alarm_permission',
      );
    });

    test('handles no won slots', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(epoch: 7, wonSlots: []),
      );

      final result = await harness.service.audit(reason: 'headless_start');

      expect(result.skippedReason, 'no_won_slots');
      expect(result.fgResumeStatus, 'no_won_slots');
      expect(harness.foregroundResumeSchedules, isEmpty);
    });

    test('collapses overlapping audits', () async {
      final epochCompleter = Completer<AlarmAuditEpochSnapshot?>();
      final harness = _AuditHarness(epochCompleter: epochCompleter);

      final first = harness.service.audit(reason: 'boot_completed');
      final second = harness.service.audit(reason: 'package_replaced');

      expect(identical(first, second), isTrue);
      epochCompleter.complete(
        const AlarmAuditEpochSnapshot(epoch: 7, wonSlots: []),
      );

      await first;
      expect(harness.loadEpochCalls, 1);
    });

    test('native recovery retries when node is not ready yet', () async {
      final retryDelays = <Duration>[];
      final retryCallbacks = <void Function()>[];
      final harness = _AuditHarness(
        nodeRunning: false,
        recoveryRetryDelays: const [Duration(milliseconds: 1)],
        scheduleRecoveryRetry: (delay, callback) {
          retryDelays.add(delay);
          retryCallbacks.add(callback);
        },
      );

      harness.service.handleNativeEvent(
        'android_alarm_recovery_requested',
        {'reason': 'boot_completed'},
      );
      await pumpEventQueue(times: 20);

      expect(
        harness.events('fg_resume_watchdog_skipped').single['skipped_reason'],
        'node_not_running',
      );
      expect(retryDelays.single, const Duration(milliseconds: 1));
      expect(retryCallbacks, hasLength(1));
      expect(harness.watchdogScheduleReasons, contains('boot_completed'));

      harness.nodeRunning = true;
      retryCallbacks.single();
      await pumpEventQueue(times: 20);

      expect(harness.foregroundResumeSchedules.single.globalSlot, 42);
      expect(harness.events('fg_resume_watchdog_recreated'), hasLength(1));
    });

    test('WorkManager watchdog event runs fg_resume reconciliation', () async {
      final harness = _AuditHarness();

      harness.service.handleNativeEvent(
        'android_workmanager_watchdog',
        {
          'reason': 'periodic',
          'startedAtMs': 12345,
          'runAttemptCount': 0,
        },
      );
      await pumpEventQueue(times: 20);

      expect(
        harness.events('android_workmanager_watchdog_started').single['reason'],
        'periodic',
      );
      expect(harness.foregroundResumeSchedules.single.globalSlot, 42);
      expect(
        harness.events('fg_resume_watchdog_recreated').single['reason'],
        'workmanager:periodic',
      );
    });

    test('foreground resume lead is four minutes in production', () {
      expect(
        AndroidForegroundTaskController.foregroundResumeLead,
        const Duration(minutes: 4),
      );
    });

    test('foreground resume present emits present telemetry', () async {
      final harness = _AuditHarness(
        presentAlarms: {'fg_resume'},
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'foreground_resume');

      expect(result.fgResumeStatus, 'present');
      expect(harness.foregroundResumeSchedules, isEmpty);
      expect(harness.events('fg_resume_watchdog_present'), hasLength(1));
    });

    test('foreground resume missing recreates fg_resume', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'cold_start');

      expect(result.fgResumeStatus, 'recreated');
      expect(harness.foregroundResumeSchedules.single.globalSlot, 42);
      expect(harness.events('fg_resume_watchdog_recreated'), hasLength(1));
    });

    test('foreground resume starts monitoring when next slot is too close',
        () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 10500),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'foreground_resume');

      expect(result.fgResumeStatus, 'slot_too_close_monitoring_started');
      expect(harness.foregroundResumeSchedules, isEmpty);
      expect(harness.monitoringReasons.single,
          'fg_resume_watchdog_slot_too_close');
      expect(
        harness.events('fg_resume_watchdog_slot_too_close'),
        hasLength(1),
      );
    });

    test('reports WorkManager watchdog state when available', () async {
      final harness = _AuditHarness(
        watchdogState: const {
          'periodic': [
            {'state': 'ENQUEUED'}
          ],
          'lastRunReason': 'periodic',
        },
      );

      await harness.service.audit(reason: 'cold_start');

      final state = harness.events('android_workmanager_watchdog_state').single;
      expect(state['reason'], 'cold_start');
      expect(state['lastRunReason'], 'periodic');
    });
  });
}

class _AuditHarness {
  _AuditHarness({
    this.exactAlarmPermission = true,
    this.epoch = const AlarmAuditEpochSnapshot(
      epoch: 7,
      wonSlots: [
        AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
      ],
    ),
    this.epochCompleter,
    Set<String>? presentAlarms,
    Map<String, AlarmDebugState>? debugStates,
    this.nodeRunning = true,
    this.recoveryRetryDelays,
    this.scheduleRecoveryRetry,
    this.watchdogState,
  })  : presentAlarms = presentAlarms ?? <String>{},
        debugStates = debugStates ?? const <String, AlarmDebugState>{} {
    service = BlockProductionAlarmAuditService.test(
      initializeAlarmService: () async => true,
      refreshPermissions: () async => exactAlarmPermission,
      hasExactAlarmPermission: () async => exactAlarmPermission,
      getAlarmDebugState: (alarmId) async =>
          this.debugStates[alarmId] ??
          AlarmDebugState(
            alarmId: alarmId,
            pendingIntentExists: this.presentAlarms.contains(alarmId),
          ),
      scheduleForegroundResume: ({
        required rustWakeTimeMs,
        required schedulerReason,
        required globalSlot,
        required slotTimeMs,
      }) async {
        foregroundResumeSchedules.add(
          _ForegroundResumeSchedule(
            rustWakeTimeMs: rustWakeTimeMs,
            schedulerReason: schedulerReason,
            globalSlot: globalSlot,
            slotTimeMs: slotTimeMs,
          ),
        );
        return ForegroundResumeAlarmScheduleResult(
          success: true,
          alarmTimeMs: slotTimeMs - foregroundResumeLead.inMilliseconds,
          delayMs: slotTimeMs - foregroundResumeLead.inMilliseconds - nowMs,
          clockDriftMs: clockDriftMs,
        );
      },
      startMonitoring: (reason) async {
        monitoringReasons.add(reason);
      },
      loadEpochSnapshot: () async {
        loadEpochCalls++;
        if (epochCompleter != null) {
          return epochCompleter!.future;
        }
        return epoch;
      },
      resolveClockDriftMs: () async => clockDriftMs,
      ensureNodeRunning: () async {
        ensureNodeRunningCalls++;
        return nodeRunning;
      },
      isNodeRunning: () => nodeRunning,
      wasForceStoppedOnStartup: () async => false,
      nowMs: () => nowMs,
      rustToLocalTimeMs: (rustTimeMs, clockDriftMs) =>
          rustTimeMs + clockDriftMs,
      lastNodeTimeMs: () => nodeTimeMs,
      lastNodeClockSampleSystemTimeMs: () => nodeClockSampleSystemTimeMs,
      isAndroid: () => true,
      appState: () => 'foreground',
      platformVersion: () => 'android-test',
      observability: _observability(records),
      foregroundResumeLead: foregroundResumeLead,
      recoveryRetryDelays: recoveryRetryDelays,
      scheduleRecoveryRetry: scheduleRecoveryRetry,
      ensureWatchdogScheduled: (reason) async {
        watchdogScheduleReasons.add(reason);
        return true;
      },
      loadWatchdogState: () async => watchdogState,
    );
  }

  static const foregroundResumeLead = Duration(milliseconds: 1000);

  final bool exactAlarmPermission;
  bool nodeRunning;
  final int clockDriftMs = 0;
  final int nowMs = 10000;
  final int nodeTimeMs = 9950;
  final int nodeClockSampleSystemTimeMs = 9950;
  final AlarmAuditEpochSnapshot? epoch;
  final Completer<AlarmAuditEpochSnapshot?>? epochCompleter;
  final List<Duration>? recoveryRetryDelays;
  final AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry;
  final Set<String> presentAlarms;
  final Map<String, AlarmDebugState> debugStates;
  final Map<String, dynamic>? watchdogState;
  final records = <_CapturedObservabilityRecord>[];
  final foregroundResumeSchedules = <_ForegroundResumeSchedule>[];
  final monitoringReasons = <String>[];
  final watchdogScheduleReasons = <String>[];
  var loadEpochCalls = 0;
  var ensureNodeRunningCalls = 0;

  late final BlockProductionAlarmAuditService service;

  List<Map<String, dynamic>> events(String event) => records
      .where((record) => record.event == event)
      .map((record) => record.payload)
      .toList(growable: false);
}

ObservabilityReportingService _observability(
  List<_CapturedObservabilityRecord> records,
) {
  final service = ObservabilityReportingService.test(
    collector: _NoopMobileContextCollector(),
    canRecord: () => true,
    record: ({
      required FlutterObservabilityKind kind,
      required String event,
      String? payloadJson,
    }) {
      records.add(
        _CapturedObservabilityRecord(
          kind: kind,
          event: event,
          payload: jsonDecode(payloadJson ?? '{}') as Map<String, dynamic>,
        ),
      );
      return const FlutterObservabilityRecordResult(
        queued: true,
        discarded: false,
      );
    },
  );
  service.markNodeInitialized();
  return service;
}

class _ForegroundResumeSchedule {
  const _ForegroundResumeSchedule({
    required this.rustWakeTimeMs,
    required this.schedulerReason,
    required this.globalSlot,
    required this.slotTimeMs,
  });

  final int rustWakeTimeMs;
  final String schedulerReason;
  final int globalSlot;
  final int slotTimeMs;
}

class _CapturedObservabilityRecord {
  const _CapturedObservabilityRecord({
    required this.kind,
    required this.event,
    required this.payload,
  });

  final FlutterObservabilityKind kind;
  final String event;
  final Map<String, dynamic> payload;
}

class _NoopMobileContextCollector implements MobileContextSnapshotCollector {
  @override
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};

  @override
  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      const {};
}
