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

    test('completed zero-win epoch schedules the epoch-boundary wake',
        () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [],
        ),
      );

      final acknowledged = await harness.service.handleNativeEvent(
        'android_workmanager_watchdog',
        {'reason': 'periodic'},
      );

      expect(acknowledged, isTrue);
      final schedule = harness.foregroundResumeSchedules.single;
      expect(schedule.schedulerReason, 'epoch_end_7');
      expect(schedule.globalSlot, 0);
    });

    test('incomplete VRF remains retryable', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: false,
          wonSlots: [],
        ),
      );

      final acknowledged = await harness.service.handleNativeEvent(
        'android_workmanager_watchdog',
        {'reason': 'periodic'},
      );

      expect(acknowledged, isFalse);
      expect(
        harness.events('fg_resume_watchdog_skipped').single['skipped_reason'],
        'vrf_incomplete',
      );
      expect(harness.foregroundResumeSchedules, isEmpty);
    });

    test('collapses overlapping audits', () async {
      final epochCompleter = Completer<AlarmAuditEpochSnapshot?>();
      final harness = _AuditHarness(epochCompleter: epochCompleter);

      final first = harness.service.audit(reason: 'boot_completed');
      final second = harness.service.audit(reason: 'package_replaced');

      expect(identical(first, second), isTrue);
      epochCompleter.complete(
        const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [],
        ),
      );

      await first;
      expect(harness.loadEpochCalls, 1);
    });

    test('native recovery leaves retries to WorkManager', () async {
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

      await harness.service.handleNativeEvent(
        'android_alarm_recovery_requested',
        {'reason': 'boot_completed'},
      );
      await pumpEventQueue(times: 20);

      expect(
        harness.events('fg_resume_watchdog_skipped').single['skipped_reason'],
        'node_not_running',
      );
      expect(retryDelays, isEmpty);
      expect(retryCallbacks, isEmpty);
      expect(harness.watchdogScheduleReasons, isEmpty);
    });

    test('WorkManager watchdog event runs fg_resume reconciliation', () async {
      final harness = _AuditHarness();

      final acknowledged = await harness.service.handleNativeEvent(
        'android_workmanager_watchdog',
        {
          'reason': 'periodic',
          'startedAtMs': 12345,
          'runAttemptCount': 0,
        },
      );

      expect(acknowledged, isTrue);
      expect(
        harness.events('android_workmanager_watchdog_started').single['reason'],
        'periodic',
      );
      expect(harness.foregroundResumeSchedules.single.globalSlot, 42);
      expect(
        harness.events('fg_resume_watchdog_recreated').single['reason'],
        'workmanager:periodic',
      );
      expect(harness.completedRecoveryAuthorities, [harness.authority]);
    });

    test('WorkManager watchdog is not acknowledged after a transient skip',
        () async {
      final retryCallbacks = <void Function()>[];
      final harness = _AuditHarness(
        nodeRunning: false,
        recoveryRetryDelays: const [Duration(milliseconds: 1)],
        scheduleRecoveryRetry: (_, callback) {
          retryCallbacks.add(callback);
        },
      );

      final acknowledged = await harness.service.handleNativeEvent(
        'android_workmanager_watchdog',
        {'reason': 'periodic'},
      );

      expect(acknowledged, isFalse);
      expect(harness.watchdogScheduleReasons, isEmpty);
      expect(retryCallbacks, isEmpty);
    });

    test('disabling recovery prevents an in-flight audit from recreating work',
        () async {
      final nodeReady = Completer<bool>();
      final harness = _AuditHarness(ensureNodeRunningCompleter: nodeReady);

      final audit = harness.service.audit(reason: 'workmanager:periodic');
      await pumpEventQueue();
      expect(harness.ensureNodeRunningCalls, 1);

      harness.service.disableWatchdogRecovery();
      nodeReady.complete(true);
      final result = await audit;

      expect(result.skippedReason, 'watchdog_disabled');
      expect(harness.watchdogScheduleReasons, isEmpty);
    });

    test('a successor lifecycle does not coalesce onto a stale audit',
        () async {
      final firstEpoch = Completer<AlarmAuditEpochSnapshot?>();
      var epochLoad = 0;
      final harness = _AuditHarness(
        epochLoader: () {
          epochLoad += 1;
          if (epochLoad == 1) return firstEpoch.future;
          return Future.value(
            const AlarmAuditEpochSnapshot(
              epoch: 8,
              vrfComplete: true,
              wonSlots: [
                AlarmAuditWonSlot(
                  globalSlot: 84,
                  expectedTimeMs: 40000,
                ),
              ],
            ),
          );
        },
      );

      final staleAudit = harness.service.audit(reason: 'generation_1');
      await pumpEventQueue();
      expect(harness.loadEpochCalls, 1);

      harness.service.disableWatchdogRecovery();
      expect(harness.service.enableWatchdogRecovery(), isTrue);
      harness.authority = const (
        generation: 2,
        bindingFingerprint: 'binding-b',
      );

      final currentAudit = harness.service.audit(reason: 'generation_2');
      final currentResult = await currentAudit;

      expect(currentResult.skippedReason, isNull);
      expect(harness.loadEpochCalls, 2);
      expect(harness.foregroundResumeSchedules, hasLength(1));
      expect(harness.foregroundResumeSchedules.single.globalSlot, 84);
      expect(harness.foregroundResumeSchedules.single.authorityGeneration, 2);

      firstEpoch.complete(
        const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
          ],
        ),
      );
      final staleResult = await staleAudit;

      expect(staleResult.skippedReason, 'watchdog_disabled');
      expect(harness.foregroundResumeSchedules, hasLength(1));
    });

    test(
        'enableWatchdogRecovery reports the disabled → enabled transition '
        'and re-arms audits', () async {
      final harness = _AuditHarness();

      // Already enabled (the default): no transition.
      expect(harness.service.enableWatchdogRecovery(), isFalse);

      harness.service.disableWatchdogRecovery();
      final disabledResult =
          await harness.service.audit(reason: 'workmanager:periodic');
      expect(disabledResult.skippedReason, 'watchdog_disabled');

      // The headless native start path (AndroidForegroundTaskController.
      // startMonitoring) relies on this returning true exactly once so it
      // can trigger the follow-up audit that reschedules the watchdog.
      expect(harness.service.enableWatchdogRecovery(), isTrue);
      expect(harness.service.enableWatchdogRecovery(), isFalse);

      final rearmedResult =
          await harness.service.audit(reason: 'native_start_rearm:alarm');
      expect(rearmedResult.skippedReason, isNull);
      expect(harness.watchdogScheduleReasons,
          contains('native_start_rearm:alarm'));
    });

    test('foreground resume lead is four minutes in production', () {
      expect(
        AndroidForegroundTaskController.foregroundResumeLead,
        const Duration(minutes: 4),
      );
    });

    test('foreground resume present emits present telemetry', () async {
      final harness = _AuditHarness(
        debugStates: const {
          'fg_resume': AlarmDebugState(
            alarmId: 'fg_resume',
            pendingIntentExists: true,
            triggerAtMs: 19000,
            globalSlot: 42,
            rustSlotTimeMs: 20000,
            slotTimeMs: 20000,
            rustWakeTimeMs: 19000,
            localWakeTimeMs: 19000,
            purpose: 'foreground_resume',
            schedulerReason: 'next_won_slot:42',
            scheduleStatus: 'scheduled',
          ),
        },
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
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

    test('foreground resume replaces a stale alarm for the wrong slot',
        () async {
      final harness = _AuditHarness(
        debugStates: const {
          'fg_resume': AlarmDebugState(
            alarmId: 'fg_resume',
            pendingIntentExists: true,
            triggerAtMs: 12000,
            globalSlot: 41,
            rustSlotTimeMs: 19000,
            slotTimeMs: 12000,
            rustWakeTimeMs: 18000,
            localWakeTimeMs: 12000,
            purpose: 'foreground_resume',
            schedulerReason: 'next_won_slot:41',
            scheduleStatus: 'failed',
          ),
        },
      );

      final result = await harness.service.audit(reason: 'foreground_resume');

      expect(result.fgResumeStatus, 'replaced');
      expect(harness.foregroundResumeSchedules.single.globalSlot, 42);
      final replacement = harness.events('fg_resume_watchdog_replaced').single;
      expect(
        replacement['mismatch_reasons'],
        containsAll(<String>[
          'global_slot',
          'trigger_time',
          'rust_slot_time',
          'rust_wake_time',
          'local_wake_time',
          'slot_time',
          'scheduler_reason',
          'schedule_status',
        ]),
      );
    });

    test('foreground resume missing recreates fg_resume', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
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

    test('reconciles fg_resume against epoch end after all won slots pass',
        () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 41, expectedTimeMs: 9000),
          ],
        ),
        epochEndTimeMs: 30000,
      );

      final result = await harness.service.audit(reason: 'workmanager');

      expect(result.fgResumeStatus, 'recreated');
      final schedule = harness.foregroundResumeSchedules.single;
      expect(schedule.schedulerReason, 'epoch_end_7');
      expect(schedule.globalSlot, 0);
      expect(schedule.rustWakeTimeMs, 29000);
      expect(schedule.slotTimeMs, 30000);
    });

    test('fails reconciliation when epoch end cannot be resolved', () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 41, expectedTimeMs: 9000),
          ],
        ),
        epochEndTimeMs: null,
      );

      final result = await harness.service.audit(reason: 'workmanager');

      expect(result.fgResumeStatus, 'epoch_end_unavailable');
      expect(result.failedCount, 1);
      expect(harness.foregroundResumeSchedules, isEmpty);
    });

    test('foreground resume starts monitoring when next slot is too close',
        () async {
      final harness = _AuditHarness(
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
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
      expect(harness.completedRecoveryAuthorities, isEmpty);
    });

    test('slot too close schedules an immediate alarm if monitoring fails',
        () async {
      final harness = _AuditHarness(
        monitoringStarts: false,
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 10500),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'workmanager');

      expect(
        result.fgResumeStatus,
        'slot_too_close_immediate_alarm_scheduled',
      );
      expect(harness.foregroundResumeSchedules.single.rustWakeTimeMs, 9500);
      expect(
        harness.events('fg_resume_watchdog_immediate_alarm_scheduled'),
        hasLength(1),
      );
    });

    test('slot too close reports failure when both recovery paths fail',
        () async {
      final harness = _AuditHarness(
        monitoringStarts: false,
        foregroundResumeScheduleSucceeds: false,
        epoch: const AlarmAuditEpochSnapshot(
          epoch: 7,
          vrfComplete: true,
          wonSlots: [
            AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 10500),
          ],
        ),
      );

      final result = await harness.service.audit(reason: 'workmanager');

      expect(result.fgResumeStatus, 'slot_too_close_recovery_failed');
      expect(result.failedCount, 1);
      expect(harness.events('fg_resume_watchdog_failed'), hasLength(1));
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
      vrfComplete: true,
      wonSlots: [
        AlarmAuditWonSlot(globalSlot: 42, expectedTimeMs: 20000),
      ],
    ),
    this.epochCompleter,
    this.epochLoader,
    Set<String>? presentAlarms,
    Map<String, AlarmDebugState>? debugStates,
    this.nodeRunning = true,
    this.recoveryRetryDelays,
    this.scheduleRecoveryRetry,
    this.watchdogState,
    this.monitoringStarts = true,
    this.foregroundResumeScheduleSucceeds = true,
    this.epochEndTimeMs = 30000,
    this.ensureNodeRunningCompleter,
    NodeRuntimeAuthority? authority,
  })  : authority = authority ??
            const (
              generation: 1,
              bindingFingerprint: 'binding-a',
            ),
        presentAlarms = presentAlarms ?? <String>{},
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
        required authority,
      }) async {
        foregroundResumeSchedules.add(
          _ForegroundResumeSchedule(
            rustWakeTimeMs: rustWakeTimeMs,
            schedulerReason: schedulerReason,
            globalSlot: globalSlot,
            slotTimeMs: slotTimeMs,
            authorityGeneration: authority.generation,
          ),
        );
        return ForegroundResumeAlarmScheduleResult(
          success: foregroundResumeScheduleSucceeds,
          alarmTimeMs: slotTimeMs - foregroundResumeLead.inMilliseconds,
          delayMs: slotTimeMs - foregroundResumeLead.inMilliseconds - nowMs,
          clockDriftMs: clockDriftMs,
          failureReason: foregroundResumeScheduleSucceeds
              ? null
              : 'platform_schedule_failed',
        );
      },
      startMonitoring: (reason, authority) async {
        monitoringReasons.add(reason);
        monitoringActive = monitoringStarts;
        return monitoringStarts;
      },
      loadEpochSnapshot: () async {
        loadEpochCalls++;
        if (epochLoader != null) {
          return epochLoader!();
        }
        if (epochCompleter != null) {
          return epochCompleter!.future;
        }
        return epoch;
      },
      loadEpochEndTimeMs: (_) async => epochEndTimeMs,
      resolveClockDriftMs: () async => clockDriftMs,
      ensureNodeRunning: () async {
        ensureNodeRunningCalls++;
        if (ensureNodeRunningCompleter != null) {
          return ensureNodeRunningCompleter!.future;
        }
        return nodeRunning;
      },
      isNodeRunning: () => nodeRunning,
      wasForceStoppedOnStartup: () async => false,
      nowMs: () => nowMs,
      rustToLocalTimeMs: (rustTimeMs, clockDriftMs) =>
          rustTimeMs + clockDriftMs,
      lastNodeTimeMs: () => nodeTimeMs,
      lastNodeClockSampleSystemTimeMs: () => nodeClockSampleSystemTimeMs,
      runtimeAuthority: () => this.authority,
      isAndroid: () => true,
      appState: () => 'foreground',
      platformVersion: () => 'android-test',
      observability: _observability(records),
      foregroundResumeLead: foregroundResumeLead,
      recoveryRetryDelays: recoveryRetryDelays,
      scheduleRecoveryRetry: scheduleRecoveryRetry,
      ensureWatchdogScheduled: (reason, authority) async {
        watchdogScheduleReasons.add(reason);
        return true;
      },
      loadWatchdogState: () async => watchdogState,
      completeRecoveryRunIfIdle: (authority) async {
        if (!monitoringActive) {
          completedRecoveryAuthorities.add(authority);
        }
      },
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
  final Future<AlarmAuditEpochSnapshot?> Function()? epochLoader;
  final List<Duration>? recoveryRetryDelays;
  final AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry;
  final Set<String> presentAlarms;
  final Map<String, AlarmDebugState> debugStates;
  final Map<String, dynamic>? watchdogState;
  final bool monitoringStarts;
  bool monitoringActive = false;
  final bool foregroundResumeScheduleSucceeds;
  final int? epochEndTimeMs;
  final Completer<bool>? ensureNodeRunningCompleter;
  NodeRuntimeAuthority authority;
  final records = <_CapturedObservabilityRecord>[];
  final foregroundResumeSchedules = <_ForegroundResumeSchedule>[];
  final monitoringReasons = <String>[];
  final watchdogScheduleReasons = <String>[];
  final completedRecoveryAuthorities = <NodeRuntimeAuthority>[];
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
    required this.authorityGeneration,
  });

  final int rustWakeTimeMs;
  final String schedulerReason;
  final int globalSlot;
  final int slotTimeMs;
  final int authorityGeneration;
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
