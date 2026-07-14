import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:crypto_mobile_app/core/models/vrf_status.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/FgResumeWatchdog');

typedef AlarmAuditScheduleForegroundResume
    = Future<ForegroundResumeAlarmScheduleResult> Function({
  required int rustWakeTimeMs,
  required String schedulerReason,
  required int globalSlot,
  required int slotTimeMs,
});

typedef AlarmAuditRecoveryRetryScheduler = void Function(
  Duration delay,
  void Function() callback,
);

typedef AlarmAuditEnsureWatchdogScheduled = Future<bool> Function(
  String reason,
);

typedef AlarmAuditLoadWatchdogState = Future<Map<String, dynamic>?> Function();

typedef AlarmAuditStartMonitoring = Future<bool> Function(String reason);

typedef AlarmAuditLoadEpochEndTimeMs = Future<int?> Function(int epoch);

class BlockProductionAlarmAuditService {
  static const _alarmStateTimeToleranceMs = 1000;

  BlockProductionAlarmAuditService._({
    Future<bool> Function()? initializeAlarmService,
    Future<bool> Function()? refreshPermissions,
    Future<bool> Function()? hasExactAlarmPermission,
    Future<bool> Function(String alarmId)? hasScheduledAlarm,
    Future<AlarmDebugState> Function(String alarmId)? getAlarmDebugState,
    AlarmAuditScheduleForegroundResume? scheduleForegroundResume,
    AlarmAuditStartMonitoring? startMonitoring,
    Future<AlarmAuditEpochSnapshot?> Function()? loadEpochSnapshot,
    AlarmAuditLoadEpochEndTimeMs? loadEpochEndTimeMs,
    Future<int?> Function()? resolveClockDriftMs,
    Future<bool> Function()? ensureNodeRunning,
    bool Function()? isNodeRunning,
    Future<bool> Function()? wasForceStoppedOnStartup,
    int Function()? nowMs,
    int Function(int rustTimeMs, int clockDriftMs)? rustToLocalTimeMs,
    int? Function()? lastNodeTimeMs,
    int? Function()? lastNodeClockSampleSystemTimeMs,
    bool Function()? isAndroid,
    String Function()? appState,
    String Function()? platformVersion,
    ObservabilityReportingService? observability,
    Duration? foregroundResumeLead,
    List<Duration>? recoveryRetryDelays,
    AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry,
    AlarmAuditEnsureWatchdogScheduled? ensureWatchdogScheduled,
    AlarmAuditLoadWatchdogState? loadWatchdogState,
  })  : _initializeAlarmService =
            initializeAlarmService ?? PlatformAlarmService.instance.initialize,
        _refreshPermissions = refreshPermissions ??
            PlatformAlarmService.instance.refreshPermissions,
        _hasExactAlarmPermission = hasExactAlarmPermission ??
            PlatformAlarmService.instance.hasExactAlarmPermission,
        _getAlarmDebugState = getAlarmDebugState ??
            (hasScheduledAlarm == null
                ? PlatformAlarmService.instance.getAlarmDebugState
                : ((alarmId) async => AlarmDebugState(
                      alarmId: alarmId,
                      pendingIntentExists: await hasScheduledAlarm(alarmId),
                    ))),
        _scheduleForegroundResume =
            scheduleForegroundResume ?? _scheduleDefaultForegroundResume,
        _startMonitoring = startMonitoring ??
            ((reason) => AndroidForegroundTaskController.instance
                .startMonitoring(reason: reason, allowWhileSleeping: true)),
        _loadEpochSnapshot = loadEpochSnapshot ?? _loadDefaultEpochSnapshot,
        _loadEpochEndTimeMs = loadEpochEndTimeMs ??
            AndroidForegroundTaskController.instance.resolveEpochEndTimeMs,
        _resolveClockDriftMs = resolveClockDriftMs ??
            RustBackendService.instance.resolveNodeClockDriftMs,
        _ensureNodeRunning = ensureNodeRunning ?? _ensureDefaultNodeRunning,
        _isNodeRunning =
            isNodeRunning ?? (() => RustBackendService.instance.isRunning),
        _wasForceStoppedOnStartup = wasForceStoppedOnStartup ??
            PlatformAlarmService.instance.wasForceStoppedOnStartup,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
        _rustToLocalTimeMs = rustToLocalTimeMs ??
            ((rustTimeMs, clockDriftMs) =>
                RustBackendService.instance.localTimeMsFromRustTimeMs(
                  rustTimeMs,
                  clockDriftMs: clockDriftMs,
                )),
        _lastNodeTimeMs = lastNodeTimeMs ??
            (() => RustBackendService.instance.lastNodeTimeMs),
        _lastNodeClockSampleSystemTimeMs = lastNodeClockSampleSystemTimeMs ??
            (() => RustBackendService.instance.lastNodeClockSampleSystemTimeMs),
        _isAndroid = isAndroid ?? (() => Platform.isAndroid),
        _appState = appState ?? _defaultAppState,
        _platformVersion =
            platformVersion ?? (() => Platform.operatingSystemVersion),
        _observability =
            observability ?? ObservabilityReportingService.instance,
        _foregroundResumeLead = foregroundResumeLead ??
            AndroidForegroundTaskController.foregroundResumeLead,
        _recoveryRetryDelays = recoveryRetryDelays ??
            const [
              Duration(seconds: 5),
              Duration(seconds: 15),
              Duration(seconds: 30),
              Duration(seconds: 60),
            ],
        _scheduleRecoveryRetry = scheduleRecoveryRetry ??
            ((delay, callback) => Timer(delay, callback)),
        _ensureWatchdogScheduled = ensureWatchdogScheduled ??
            ((reason) => PlatformAlarmService.instance
                .ensureAlarmWatchdogScheduled(reason: reason)),
        _loadWatchdogState = loadWatchdogState ??
            PlatformAlarmService.instance.getAlarmWatchdogState;

  @visibleForTesting
  BlockProductionAlarmAuditService.test({
    Future<bool> Function()? initializeAlarmService,
    Future<bool> Function()? refreshPermissions,
    Future<bool> Function()? hasExactAlarmPermission,
    Future<bool> Function(String alarmId)? hasScheduledAlarm,
    Future<AlarmDebugState> Function(String alarmId)? getAlarmDebugState,
    AlarmAuditScheduleForegroundResume? scheduleForegroundResume,
    AlarmAuditStartMonitoring? startMonitoring,
    Future<AlarmAuditEpochSnapshot?> Function()? loadEpochSnapshot,
    AlarmAuditLoadEpochEndTimeMs? loadEpochEndTimeMs,
    Future<int?> Function()? resolveClockDriftMs,
    Future<bool> Function()? ensureNodeRunning,
    bool Function()? isNodeRunning,
    Future<bool> Function()? wasForceStoppedOnStartup,
    int Function()? nowMs,
    int Function(int rustTimeMs, int clockDriftMs)? rustToLocalTimeMs,
    int? Function()? lastNodeTimeMs,
    int? Function()? lastNodeClockSampleSystemTimeMs,
    bool Function()? isAndroid,
    String Function()? appState,
    String Function()? platformVersion,
    required ObservabilityReportingService observability,
    Duration? foregroundResumeLead,
    List<Duration>? recoveryRetryDelays,
    AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry,
    AlarmAuditEnsureWatchdogScheduled? ensureWatchdogScheduled,
    AlarmAuditLoadWatchdogState? loadWatchdogState,
  }) : this._(
          initializeAlarmService: initializeAlarmService,
          refreshPermissions: refreshPermissions,
          hasExactAlarmPermission: hasExactAlarmPermission,
          hasScheduledAlarm: hasScheduledAlarm,
          getAlarmDebugState: getAlarmDebugState,
          scheduleForegroundResume: scheduleForegroundResume,
          startMonitoring: startMonitoring,
          loadEpochSnapshot: loadEpochSnapshot,
          loadEpochEndTimeMs: loadEpochEndTimeMs,
          resolveClockDriftMs: resolveClockDriftMs,
          ensureNodeRunning: ensureNodeRunning,
          isNodeRunning: isNodeRunning,
          wasForceStoppedOnStartup: wasForceStoppedOnStartup,
          nowMs: nowMs,
          rustToLocalTimeMs: rustToLocalTimeMs,
          lastNodeTimeMs: lastNodeTimeMs,
          lastNodeClockSampleSystemTimeMs: lastNodeClockSampleSystemTimeMs,
          isAndroid: isAndroid,
          appState: appState,
          platformVersion: platformVersion,
          observability: observability,
          foregroundResumeLead: foregroundResumeLead,
          recoveryRetryDelays: recoveryRetryDelays,
          scheduleRecoveryRetry: scheduleRecoveryRetry,
          ensureWatchdogScheduled: ensureWatchdogScheduled,
          loadWatchdogState: loadWatchdogState,
        );

  static final BlockProductionAlarmAuditService instance =
      BlockProductionAlarmAuditService._();

  final Future<bool> Function() _initializeAlarmService;
  final Future<bool> Function() _refreshPermissions;
  final Future<bool> Function() _hasExactAlarmPermission;
  final Future<AlarmDebugState> Function(String alarmId) _getAlarmDebugState;
  final AlarmAuditScheduleForegroundResume _scheduleForegroundResume;
  final AlarmAuditStartMonitoring _startMonitoring;
  final Future<AlarmAuditEpochSnapshot?> Function() _loadEpochSnapshot;
  final AlarmAuditLoadEpochEndTimeMs _loadEpochEndTimeMs;
  final Future<int?> Function() _resolveClockDriftMs;
  final Future<bool> Function() _ensureNodeRunning;
  final bool Function() _isNodeRunning;
  final Future<bool> Function() _wasForceStoppedOnStartup;
  final int Function() _nowMs;
  final int Function(int rustTimeMs, int clockDriftMs) _rustToLocalTimeMs;
  final int? Function() _lastNodeTimeMs;
  final int? Function() _lastNodeClockSampleSystemTimeMs;
  final bool Function() _isAndroid;
  final String Function() _appState;
  final String Function() _platformVersion;
  final ObservabilityReportingService _observability;
  final Duration _foregroundResumeLead;
  final List<Duration> _recoveryRetryDelays;
  final AlarmAuditRecoveryRetryScheduler _scheduleRecoveryRetry;
  final AlarmAuditEnsureWatchdogScheduled _ensureWatchdogScheduled;
  final AlarmAuditLoadWatchdogState _loadWatchdogState;

  Future<AlarmAuditResult>? _inFlight;
  bool _forceStopChecked = false;
  String? _pendingRecoveryReason;
  var _recoveryRetryAttempt = 0;
  var _recoveryRetryGeneration = 0;
  bool _watchdogRecoveryEnabled = true;
  var _watchdogLifecycleGeneration = 0;

  void enableWatchdogRecovery() {
    if (_watchdogRecoveryEnabled) return;
    _watchdogRecoveryEnabled = true;
    _watchdogLifecycleGeneration += 1;
  }

  void disableWatchdogRecovery() {
    if (!_watchdogRecoveryEnabled) return;
    _watchdogRecoveryEnabled = false;
    _watchdogLifecycleGeneration += 1;
    _pendingRecoveryReason = null;
    _recoveryRetryAttempt = 0;
    _recoveryRetryGeneration += 1;
  }

  void auditBestEffort({required String reason}) {
    if (!_watchdogRecoveryEnabled) return;
    _auditBestEffort(reason: reason);
  }

  Future<bool> auditForceStopRecoveryIfNeeded() async {
    if (_forceStopChecked || !_isAndroid()) {
      return false;
    }

    _forceStopChecked = true;
    final detected = await _wasForceStoppedOnStartup();
    if (!detected) {
      return false;
    }

    _report(
      'app_restarted_after_force_stop',
      {
        'platform_version': _platformVersion(),
        'app_state': _appState(),
      },
    );
    _auditBestEffort(
      reason: 'force_stop_recovery',
      retryTransientRecovery: true,
    );
    return true;
  }

  Future<bool> handleNativeEvent(
    String eventType,
    Map<String, dynamic> eventData,
  ) async {
    switch (eventType) {
      case 'android_alarm_recovery_requested':
        final reason = _stringValue(eventData['reason']) ?? 'native_recovery';
        _log.warn('Alarm recovery event delivered', context: {
          'reason': reason,
          ...eventData,
        });
        // Boot/package recovery also queues WorkManager, which owns retries.
        _auditBestEffort(reason: reason);
        return true;
      case 'android_workmanager_watchdog':
        final reason = _stringValue(eventData['reason']) ?? 'workmanager';
        _report(
          'android_workmanager_watchdog_started',
          {
            'reason': reason,
            ...eventData,
          },
        );
        final auditReason = 'workmanager:$reason';
        final result = await audit(reason: auditReason);
        return _watchdogResultAcknowledged(result);
      case 'android_exact_alarm_permission_granted':
        final stateChanged = eventData['stateChanged'] == true;
        final source = _stringValue(eventData['source']);
        if (stateChanged || source == 'permission_state_changed_broadcast') {
          _auditBestEffort(
            reason: 'exact_alarm_permission_granted',
            retryTransientRecovery: true,
          );
        }
        return true;
      default:
        return true;
    }
  }

  bool _watchdogResultAcknowledged(AlarmAuditResult result) {
    final skippedReason = result.skippedReason;
    if (skippedReason != null) {
      return !_isTransientRecoverySkip(skippedReason) &&
          skippedReason != 'audit_exception';
    }
    return result.failedCount == 0;
  }

  void _auditBestEffort({
    required String reason,
    bool retryTransientRecovery = false,
  }) {
    if (retryTransientRecovery) {
      _pendingRecoveryReason = reason;
    }

    unawaited(
      audit(reason: reason).then((result) {
        if (retryTransientRecovery) {
          _handleRecoveryAuditResult(reason: reason, result: result);
        }
      }),
    );
  }

  void _handleRecoveryAuditResult({
    required String reason,
    required AlarmAuditResult result,
  }) {
    if (_pendingRecoveryReason != reason) {
      return;
    }

    final skippedReason = result.skippedReason;
    if (skippedReason == null || !_isTransientRecoverySkip(skippedReason)) {
      _log.warn('fg_resume watchdog recovery finished without retry', context: {
        'reason': reason,
        if (skippedReason != null) 'skipped_reason': skippedReason,
        'fg_resume_status': result.fgResumeStatus,
      });
      _clearPendingRecovery(reason);
      return;
    }

    if (_recoveryRetryAttempt >= _recoveryRetryDelays.length) {
      _log.warn('fg_resume watchdog recovery retries exhausted', context: {
        'reason': reason,
        'skipped_reason': skippedReason,
        'attempts': _recoveryRetryAttempt,
      });
      _clearPendingRecovery(reason);
      return;
    }

    final delay = _recoveryRetryDelays[_recoveryRetryAttempt];
    _recoveryRetryAttempt += 1;
    final generation = ++_recoveryRetryGeneration;
    _log.warn('fg_resume watchdog will retry after transient skip', context: {
      'reason': reason,
      'skipped_reason': skippedReason,
      'attempt': _recoveryRetryAttempt,
      'delay_ms': delay.inMilliseconds,
    });

    _scheduleRecoveryRetry(delay, () {
      if (_pendingRecoveryReason != reason ||
          _recoveryRetryGeneration != generation) {
        return;
      }
      _auditBestEffort(reason: reason, retryTransientRecovery: true);
    });
  }

  void _clearPendingRecovery(String reason) {
    if (_pendingRecoveryReason != reason) {
      return;
    }

    _pendingRecoveryReason = null;
    _recoveryRetryAttempt = 0;
    _recoveryRetryGeneration += 1;
  }

  bool _isTransientRecoverySkip(String skippedReason) {
    return skippedReason == 'node_not_running' ||
        skippedReason == 'clock_drift_unavailable' ||
        skippedReason == 'epoch_info_unavailable' ||
        skippedReason == 'vrf_incomplete';
  }

  Future<AlarmAuditResult> audit({required String reason}) {
    final active = _inFlight;
    if (active != null) {
      return active;
    }

    late final Future<AlarmAuditResult> future;
    future = _runAudit(reason).whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    _inFlight = future;
    return future;
  }

  Future<AlarmAuditResult> _runAudit(String reason) async {
    try {
      if (!_isAndroid()) {
        return _skip(reason, 'unsupported_platform');
      }

      final lifecycleGeneration = _watchdogLifecycleGeneration;
      if (!_isWatchdogRecoveryActive(lifecycleGeneration)) {
        return _skip(
          reason,
          'watchdog_disabled',
          fgResumeStatus: 'skipped:watchdog_disabled',
        );
      }

      await _initializeAlarmService();
      await _refreshPermissions();

      final exactAlarmPermission = await _hasExactAlarmPermission();
      _reportStarted(
        reason: reason,
        exactAlarmPermission: exactAlarmPermission,
      );

      if (!exactAlarmPermission) {
        if (_isWatchdogRecoveryActive(lifecycleGeneration) &&
            _isNodeRunning()) {
          await _ensureWatchdogScheduled(reason);
          await _reportWatchdogState(reason);
        }
        return _skip(
          reason,
          'no_exact_alarm_permission',
          fgResumeStatus: 'skipped:no_exact_alarm_permission',
        );
      }

      final nodeRunning = await _ensureNodeRunning();
      if (!nodeRunning) {
        return _skip(
          reason,
          'node_not_running',
          fgResumeStatus: 'skipped:node_not_running',
        );
      }

      if (!_isWatchdogRecoveryActive(lifecycleGeneration)) {
        return _skip(
          reason,
          'watchdog_disabled',
          fgResumeStatus: 'skipped:watchdog_disabled',
        );
      }

      await _ensureWatchdogScheduled(reason);
      await _reportWatchdogState(reason);

      final clockDriftMs = await _resolveClockDriftMs();
      if (clockDriftMs == null) {
        return _skip(
          reason,
          'clock_drift_unavailable',
          fgResumeStatus: 'skipped:clock_drift_unavailable',
        );
      }

      final epoch = await _loadEpochSnapshot();
      if (epoch == null) {
        return _skip(
          reason,
          'epoch_info_unavailable',
          fgResumeStatus: 'skipped:epoch_info_unavailable',
        );
      }

      if (!epoch.vrfComplete) {
        return _skip(
          reason,
          'vrf_incomplete',
          fgResumeStatus: 'vrf_incomplete',
        );
      }

      final fgResumeStatus = await _auditForegroundResume(
        reason: reason,
        epoch: epoch,
        clockDriftMs: clockDriftMs,
      );

      _reportCompleted(reason: reason, fgResumeStatus: fgResumeStatus);

      return AlarmAuditResult(
        reason: reason,
        expectedSlotWakeCount: 0,
        presentCount: fgResumeStatus == 'present' ? 1 : 0,
        missingCount: fgResumeStatus == 'recreated' ? 1 : 0,
        rescheduledCount: const {
          'recreated',
          'replaced',
          'slot_too_close_immediate_alarm_scheduled',
        }.contains(fgResumeStatus)
            ? 1
            : 0,
        failedCount: const {
          'reschedule_failed',
          'slot_too_close_recovery_failed',
          'epoch_end_unavailable',
        }.contains(fgResumeStatus)
            ? 1
            : 0,
        fgResumeStatus: fgResumeStatus,
      );
    } catch (e, st) {
      _log.error('fg_resume watchdog failed: $e', error: e, stackTrace: st);
      return _skip(
        reason,
        'audit_exception',
        failureReason: e.toString(),
        fgResumeStatus: 'skipped:audit_exception',
      );
    }
  }

  bool _isWatchdogRecoveryActive(int lifecycleGeneration) {
    return _watchdogRecoveryEnabled &&
        lifecycleGeneration == _watchdogLifecycleGeneration;
  }

  Future<String> _auditForegroundResume({
    required String reason,
    required AlarmAuditEpochSnapshot epoch,
    required int clockDriftMs,
  }) async {
    final nowMs = _nowMs();
    final nextWonSlot = _nextFutureWonSlot(
      epoch.wonSlots,
      clockDriftMs: clockDriftMs,
      nowMs: nowMs,
    );

    late final _ForegroundResumeTarget target;
    late final String schedulerReason;
    if (nextWonSlot != null) {
      target = nextWonSlot;
      schedulerReason = 'next_won_slot:${target.globalSlot}';
    } else {
      final epochEndRustTimeMs = await _loadEpochEndTimeMs(epoch.epoch);
      if (epochEndRustTimeMs == null) {
        _report(
          'fg_resume_watchdog_failed',
          {
            'reason': reason,
            'epoch': epoch.epoch,
            'failure_reason': 'epoch_end_time_unavailable',
          },
        );
        return 'epoch_end_unavailable';
      }

      target = _ForegroundResumeTarget(
        globalSlot: 0,
        rustSlotTimeMs: epochEndRustTimeMs,
        slotTimeMs: _rustToLocalTimeMs(epochEndRustTimeMs, clockDriftMs),
      );
      schedulerReason = 'epoch_end_${epoch.epoch}';
    }

    final fgLeadMs = _foregroundResumeLead.inMilliseconds;
    final alarm = AlarmAuditExpectedAlarm(
      alarmId: AndroidForegroundTaskController.foregroundResumeAlarmId,
      purpose: 'foreground_resume',
      globalSlot: target.globalSlot,
      epoch: epoch.epoch,
      rustSlotTimeMs: target.rustSlotTimeMs,
      slotTimeMs: target.slotTimeMs,
      alarmTimeMs: target.slotTimeMs - fgLeadMs,
      clockDriftMs: clockDriftMs,
      nodeTimeMsAtAudit: _lastNodeTimeMs(),
      systemTimeMsAtAudit: nowMs,
      clockDriftSampleAgeMs: _clockDriftSampleAgeMs(nowMs),
    );
    if (target.slotTimeMs - nowMs <= fgLeadMs) {
      var monitoringStarted = false;
      String? monitoringFailure;
      try {
        monitoringStarted =
            await _startMonitoring('fg_resume_watchdog_slot_too_close');
      } catch (e, st) {
        monitoringFailure = e.toString();
        _log.warn('Failed to start imminent-slot monitoring: $e');
        _log.debug('$st');
      }
      _report(
        'fg_resume_watchdog_slot_too_close',
        {
          'reason': reason,
          'global_slot': target.globalSlot,
          'slot_time_ms': target.slotTimeMs,
          'now_ms': nowMs,
          'monitoring_started': monitoringStarted,
          if (monitoringFailure != null)
            'monitoring_failure': monitoringFailure,
        },
      );
      if (monitoringStarted) {
        return 'slot_too_close_monitoring_started';
      }

      final fallback = await _scheduleForegroundResume(
        rustWakeTimeMs: alarm.rustSlotTimeMs - fgLeadMs,
        schedulerReason: schedulerReason,
        globalSlot: alarm.globalSlot,
        slotTimeMs: alarm.slotTimeMs,
      );
      if (fallback.success) {
        _report(
          'fg_resume_watchdog_immediate_alarm_scheduled',
          {
            'reason': reason,
            ...alarm
                .copyWith(
                  alarmTimeMs: fallback.alarmTimeMs ?? alarm.alarmTimeMs,
                )
                .telemetryDetails,
            'schedule_success': true,
          },
        );
        return 'slot_too_close_immediate_alarm_scheduled';
      }

      _report(
        'fg_resume_watchdog_failed',
        {
          'reason': reason,
          ...alarm.telemetryDetails,
          'failure_reason':
              fallback.failureReason ?? 'immediate_alarm_schedule_failed',
        },
      );
      return 'slot_too_close_recovery_failed';
    }

    final state = await _getAlarmDebugState(alarm.alarmId);
    final mismatches = _foregroundResumeMismatches(
      expected: alarm,
      state: state,
      schedulerReason: schedulerReason,
    );
    if (mismatches.isEmpty) {
      _report(
        'fg_resume_watchdog_present',
        {
          'reason': reason,
          ...alarm.telemetryDetails,
          ...state.telemetryDetails,
        },
      );
      return 'present';
    }

    final result = await _scheduleForegroundResume(
      rustWakeTimeMs: alarm.rustSlotTimeMs - fgLeadMs,
      schedulerReason: schedulerReason,
      globalSlot: alarm.globalSlot,
      slotTimeMs: alarm.slotTimeMs,
    );
    final scheduledAlarm = alarm.copyWith(
      alarmTimeMs: result.alarmTimeMs ?? alarm.alarmTimeMs,
    );

    if (result.success) {
      final status = state.pendingIntentExists ? 'replaced' : 'recreated';
      _report(
        'fg_resume_watchdog_$status',
        {
          'reason': reason,
          ...scheduledAlarm.telemetryDetails,
          'schedule_success': true,
          'mismatch_reasons': mismatches,
          ...state.telemetryDetails,
        },
      );
      return status;
    }

    _report(
      'fg_resume_watchdog_failed',
      {
        'reason': reason,
        ...scheduledAlarm.telemetryDetails,
        'failure_reason': result.failureReason ?? 'platform_schedule_failed',
        'mismatch_reasons': mismatches,
        ...state.telemetryDetails,
      },
    );
    return 'reschedule_failed';
  }

  List<String> _foregroundResumeMismatches({
    required AlarmAuditExpectedAlarm expected,
    required AlarmDebugState state,
    required String schedulerReason,
  }) {
    if (!state.pendingIntentExists) {
      return const ['pending_intent_missing'];
    }

    final mismatches = <String>[];
    if (state.globalSlot != expected.globalSlot) {
      mismatches.add('global_slot');
    }
    final triggerAtMs = state.triggerAtMs;
    if (triggerAtMs == null) {
      mismatches.add('trigger_time_missing');
    } else if ((triggerAtMs - expected.alarmTimeMs).abs() >
        _alarmStateTimeToleranceMs) {
      mismatches.add('trigger_time');
    }
    if (state.rustSlotTimeMs != expected.rustSlotTimeMs) {
      mismatches.add('rust_slot_time');
    }
    if (state.rustWakeTimeMs !=
        expected.rustSlotTimeMs - _foregroundResumeLead.inMilliseconds) {
      mismatches.add('rust_wake_time');
    }
    final localWakeTimeMs = state.localWakeTimeMs;
    if (localWakeTimeMs == null) {
      mismatches.add('local_wake_time_missing');
    } else if ((localWakeTimeMs - expected.alarmTimeMs).abs() >
        _alarmStateTimeToleranceMs) {
      mismatches.add('local_wake_time');
    }
    final slotTimeMs = state.slotTimeMs;
    if (slotTimeMs == null) {
      mismatches.add('slot_time_missing');
    } else if ((slotTimeMs - expected.slotTimeMs).abs() >
        _alarmStateTimeToleranceMs) {
      mismatches.add('slot_time');
    }
    if (state.purpose != expected.purpose) {
      mismatches.add('purpose');
    }
    if (state.schedulerReason != schedulerReason) {
      mismatches.add('scheduler_reason');
    }
    if (state.scheduleStatus != 'scheduled') {
      mismatches.add('schedule_status');
    }
    return mismatches;
  }

  _ForegroundResumeTarget? _nextFutureWonSlot(
    List<AlarmAuditWonSlot> slots, {
    required int clockDriftMs,
    required int nowMs,
  }) {
    final futureSlots = slots
        .map((slot) {
          final slotTimeMs = _rustToLocalTimeMs(
            slot.expectedTimeMs,
            clockDriftMs,
          );
          return _ForegroundResumeTarget(
            globalSlot: slot.globalSlot,
            rustSlotTimeMs: slot.expectedTimeMs,
            slotTimeMs: slotTimeMs,
          );
        })
        .where((slot) => slot.slotTimeMs > nowMs)
        .toList()
      ..sort((a, b) => a.slotTimeMs.compareTo(b.slotTimeMs));

    return futureSlots.isEmpty ? null : futureSlots.first;
  }

  int? _clockDriftSampleAgeMs(int systemTimeMs) {
    final sampleSystemTimeMs = _lastNodeClockSampleSystemTimeMs();
    if (sampleSystemTimeMs == null) return null;
    return systemTimeMs - sampleSystemTimeMs;
  }

  Future<void> _reportWatchdogState(String reason) async {
    final state = await _loadWatchdogState();
    if (state == null) return;
    _report(
      'android_workmanager_watchdog_state',
      {
        'reason': reason,
        ...state,
      },
    );
  }

  void _reportStarted({
    required String reason,
    required bool exactAlarmPermission,
  }) {
    _report(
      'fg_resume_watchdog_started',
      {
        'reason': reason,
        'app_state': _appState(),
        'platform_version': _platformVersion(),
        'exact_alarm_permission': exactAlarmPermission,
        'node_running': _isNodeRunning(),
      },
    );
  }

  AlarmAuditResult _skip(
    String reason,
    String skippedReason, {
    String fgResumeStatus = 'skipped',
    String? failureReason,
  }) {
    _log.info('fg_resume watchdog skipped', context: {
      'reason': reason,
      'skipped_reason': skippedReason,
      if (failureReason != null) 'failure_reason': failureReason,
    });
    _report(
      'fg_resume_watchdog_skipped',
      {
        'reason': reason,
        'skipped_reason': skippedReason,
        if (failureReason != null) 'failure_reason': failureReason,
      },
    );
    _reportCompleted(reason: reason, fgResumeStatus: fgResumeStatus);

    return AlarmAuditResult(
      reason: reason,
      skippedReason: skippedReason,
      expectedSlotWakeCount: 0,
      presentCount: 0,
      missingCount: 0,
      rescheduledCount: 0,
      failedCount: 0,
      fgResumeStatus: fgResumeStatus,
    );
  }

  void _reportCompleted({
    required String reason,
    required String fgResumeStatus,
  }) {
    _log.info('fg_resume watchdog completed', context: {
      'reason': reason,
      'fg_resume_status': fgResumeStatus,
    });
    _report(
      'fg_resume_watchdog_completed',
      {
        'reason': reason,
        'fg_resume_status': fgResumeStatus,
      },
    );
  }

  void _report(String event, Map<String, dynamic> details) {
    _observability.reportBlockProductionAlarmAuditEvent(
      event: event,
      details: details,
    );
  }

  static Future<AlarmAuditEpochSnapshot?> _loadDefaultEpochSnapshot() async {
    final info = await RustBackendService.instance.getEpochInfo();
    if (info == null) {
      return null;
    }

    return AlarmAuditEpochSnapshot(
      epoch: info.currentEpoch,
      vrfComplete: info.vrfStatus == VRFStatus.complete,
      wonSlots: info.wonSlots
          .map(
            (slot) => AlarmAuditWonSlot(
              globalSlot: slot.globalSlot,
              expectedTimeMs: slot.expectedTimeMs.toInt(),
            ),
          )
          .toList(growable: false),
    );
  }

  static Future<bool> _ensureDefaultNodeRunning() async {
    try {
      final started = await RustBackendService.instance.startNode();
      if (started) {
        await RustBackendService.instance.resumeNode();
      }
      return started;
    } catch (e, st) {
      _log.warn('Failed to ensure node is running: $e');
      _log.debug('$st');
      return false;
    }
  }

  static Future<ForegroundResumeAlarmScheduleResult>
      _scheduleDefaultForegroundResume({
    required int rustWakeTimeMs,
    required String schedulerReason,
    required int globalSlot,
    required int slotTimeMs,
  }) {
    return AndroidForegroundTaskController.instance.scheduleResumeAlarm(
      rustWakeTimeMs: rustWakeTimeMs,
      reason: schedulerReason,
      targetGlobalSlot: globalSlot,
      targetRustSlotTimeMs: rustWakeTimeMs +
          AndroidForegroundTaskController.foregroundResumeLead.inMilliseconds,
      targetSlotTimeMs: slotTimeMs,
      stopMonitoringAfterSchedule: false,
    );
  }

  static String _defaultAppState() {
    try {
      return WidgetsBinding.instance.lifecycleState?.name ?? 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  String? _stringValue(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}

class AlarmAuditEpochSnapshot {
  const AlarmAuditEpochSnapshot({
    required this.epoch,
    required this.vrfComplete,
    required this.wonSlots,
  });

  final int epoch;
  final bool vrfComplete;
  final List<AlarmAuditWonSlot> wonSlots;
}

class AlarmAuditWonSlot {
  const AlarmAuditWonSlot({
    required this.globalSlot,
    required this.expectedTimeMs,
  });

  final int globalSlot;
  final int expectedTimeMs;
}

class AlarmAuditExpectedAlarm {
  const AlarmAuditExpectedAlarm({
    required this.alarmId,
    required this.purpose,
    required this.globalSlot,
    required this.epoch,
    required this.rustSlotTimeMs,
    required this.slotTimeMs,
    required this.alarmTimeMs,
    required this.clockDriftMs,
    this.nodeTimeMsAtAudit,
    this.systemTimeMsAtAudit,
    this.clockDriftSampleAgeMs,
  });

  final String alarmId;
  final String purpose;
  final int globalSlot;
  final int epoch;
  final int rustSlotTimeMs;
  final int slotTimeMs;
  final int alarmTimeMs;
  final int clockDriftMs;
  final int? nodeTimeMsAtAudit;
  final int? systemTimeMsAtAudit;
  final int? clockDriftSampleAgeMs;

  AlarmAuditExpectedAlarm copyWith({int? alarmTimeMs}) {
    return AlarmAuditExpectedAlarm(
      alarmId: alarmId,
      purpose: purpose,
      globalSlot: globalSlot,
      epoch: epoch,
      rustSlotTimeMs: rustSlotTimeMs,
      slotTimeMs: slotTimeMs,
      alarmTimeMs: alarmTimeMs ?? this.alarmTimeMs,
      clockDriftMs: clockDriftMs,
      nodeTimeMsAtAudit: nodeTimeMsAtAudit,
      systemTimeMsAtAudit: systemTimeMsAtAudit,
      clockDriftSampleAgeMs: clockDriftSampleAgeMs,
    );
  }

  Map<String, dynamic> get telemetryDetails => {
        'alarm_id': alarmId,
        'purpose': purpose,
        'global_slot': globalSlot,
        'epoch': epoch,
        'rust_slot_time_ms': rustSlotTimeMs,
        'slot_time_ms': slotTimeMs,
        'alarm_time_ms': alarmTimeMs,
        'clock_drift_ms': clockDriftMs,
        if (nodeTimeMsAtAudit != null) 'audit_node_time_ms': nodeTimeMsAtAudit,
        if (systemTimeMsAtAudit != null)
          'audit_system_time_ms': systemTimeMsAtAudit,
        if (clockDriftSampleAgeMs != null)
          'audit_clock_drift_sample_age_ms': clockDriftSampleAgeMs,
      };
}

class _ForegroundResumeTarget {
  const _ForegroundResumeTarget({
    required this.globalSlot,
    required this.rustSlotTimeMs,
    required this.slotTimeMs,
  });

  final int globalSlot;
  final int rustSlotTimeMs;
  final int slotTimeMs;
}

class AlarmAuditResult {
  const AlarmAuditResult({
    required this.reason,
    this.skippedReason,
    this.expectedSlotWakeCount = 0,
    this.presentCount = 0,
    this.missingCount = 0,
    this.rescheduledCount = 0,
    this.failedCount = 0,
    this.fgResumeStatus = 'unknown',
  });

  final String reason;
  final String? skippedReason;
  final int expectedSlotWakeCount;
  final int presentCount;
  final int missingCount;
  final int rescheduledCount;
  final int failedCount;
  final String fgResumeStatus;
}
