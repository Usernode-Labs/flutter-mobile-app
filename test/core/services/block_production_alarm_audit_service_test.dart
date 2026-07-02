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
      expect(harness.scheduledAlarms, isEmpty);
      expect(
        harness.events('alarm_audit_skipped').single['skipped_reason'],
        'no_exact_alarm_permission',
      );
    });

    test('reschedules a missing future slot_wake alarm', () async {
      final harness = _AuditHarness(
        presentAlarms: {'fg_resume'},
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'cold_start');

      expect(result.expectedSlotWakeCount, 1);
      expect(result.missingCount, 1);
      expect(result.rescheduledCount, 1);
      expect(harness.scheduledAlarms.single.alarmId, 'slot_42');
      expect(harness.scheduledAlarms.single.globalSlot, 42);
      expect(
        harness.events('alarm_audit_missing_rescheduled').single['purpose'],
        'slot_wake',
      );
    });

    test(
        'classifies past slot_wake alarm with no receiver and no pending intent',
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

      expect(result.expectedSlotWakeCount, 0);
      expect(result.missingCount, 0);
      expect(harness.scheduledAlarms, isEmpty);
      final missing =
          harness.events('alarm_audit_past_missing_no_receiver').single;
      expect(missing['alarm_id'], 'slot_42');
      expect(missing['past_alarm_age_ms'], 500);
      expect(missing['native_pending_intent_exists'], isFalse);
      final completed = harness.events('alarm_audit_completed').single;
      expect(completed['past_slot_wake_count'], 1);
      expect(completed['past_missing_no_receiver_count'], 1);
    });

    test(
        'classifies past slot_wake alarm delivered after slot as receiver late',
        () async {
      final harness = _AuditHarness(
        debugStates: const {
          'slot_42': AlarmDebugState(
            alarmId: 'slot_42',
            pendingIntentExists: false,
            receiverEnteredAtMs: 9600,
            receiverLatencyMs: 1100,
          ),
        },
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 9500),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'foreground_resume');

      expect(result.expectedSlotWakeCount, 0);
      expect(harness.scheduledAlarms, isEmpty);
      final late = harness.events('alarm_audit_past_receiver_late').single;
      expect(late['alarm_id'], 'slot_42');
      expect(late['delivery_latency_ms'], 1100);
      expect(late['slot_delta_ms'], 100);
      expect(late['ledger_receiver_entered_at_ms'], 9600);
    });

    test('handles no won slots', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(epoch: 7, wonSlots: []),
      );

      final result = await harness.service.audit(reason: 'headless_start');

      expect(result.skippedReason, 'no_won_slots');
      expect(result.fgResumeStatus, 'no_won_slots');
      expect(harness.scheduledAlarms, isEmpty);
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
        harness.events('alarm_audit_skipped').single['skipped_reason'],
        'node_not_running',
      );
      expect(retryDelays.single, const Duration(milliseconds: 1));
      expect(retryCallbacks, hasLength(1));

      harness.nodeRunning = true;
      retryCallbacks.single();
      await pumpEventQueue(times: 20);

      expect(harness.scheduledAlarms.single.alarmId, 'slot_42');
      final slotWakeEvents = harness
          .events('alarm_audit_missing_rescheduled')
          .where((event) => event['purpose'] == 'slot_wake');
      expect(slotWakeEvents, hasLength(1));
    });

    test('native recovery retries when won slots are not available yet',
        () async {
      final retryCallbacks = <void Function()>[];
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(epoch: 7, wonSlots: []),
        recoveryRetryDelays: const [Duration(milliseconds: 1)],
        scheduleRecoveryRetry: (_, callback) {
          retryCallbacks.add(callback);
        },
      );

      harness.service.handleNativeEvent(
        'android_alarm_recovery_requested',
        {'reason': 'boot_completed'},
      );
      await pumpEventQueue(times: 20);

      expect(
        harness.events('alarm_audit_skipped').single['skipped_reason'],
        'no_won_slots',
      );
      expect(retryCallbacks, hasLength(1));
    });

    test('foreground resume lead is four minutes in production', () {
      expect(
        AndroidForegroundTaskController.foregroundResumeLead,
        const Duration(minutes: 4),
      );
    });

    test('foreground resume present emits present telemetry', () async {
      final harness = _AuditHarness(
        presentAlarms: {'slot_42', 'fg_resume'},
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
      expect(harness.events('foreground_resume_present'), hasLength(1));
    });

    test('foreground resume missing recreates fg_resume', () async {
      final harness = _AuditHarness(
        presentAlarms: {'slot_42'},
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
      expect(harness.events('foreground_resume_recreated'), hasLength(1));
    });

    test('foreground resume skips when next slot is too close', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 10500),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'foreground_resume');

      expect(result.fgResumeStatus, 'slot_too_close');
      expect(harness.foregroundResumeSchedules, isEmpty);
      expect(
        harness.events('foreground_resume_not_scheduled_slot_too_close'),
        hasLength(1),
      );
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
      scheduleAlarm: ({
        required alarmId,
        required globalSlot,
        required delayMs,
        data,
      }) async {
        scheduledAlarms.add(
          _ScheduledAlarm(
            alarmId: alarmId,
            globalSlot: globalSlot,
            delayMs: delayMs,
            data: data ?? const {},
          ),
        );
        return true;
      },
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
      slotWakeLead: slotWakeLead,
      foregroundResumeLead: foregroundResumeLead,
      recoveryRetryDelays: recoveryRetryDelays,
      scheduleRecoveryRetry: scheduleRecoveryRetry,
    );
  }

  static const slotWakeLead = Duration(milliseconds: 1000);
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
  final records = <_CapturedObservabilityRecord>[];
  final scheduledAlarms = <_ScheduledAlarm>[];
  final foregroundResumeSchedules = <_ForegroundResumeSchedule>[];
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

class _ScheduledAlarm {
  const _ScheduledAlarm({
    required this.alarmId,
    required this.globalSlot,
    required this.delayMs,
    required this.data,
  });

  final String alarmId;
  final int globalSlot;
  final int delayMs;
  final Map<String, dynamic> data;
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
  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      {};

  @override
  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      {};

  @override
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    Map<String, dynamic>? eventData,
  }) async =>
      {};
}
