import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

final _log = LoggingService.instance.withTag('usernode/AlarmAudit');

typedef AlarmAuditScheduleAlarm = Future<bool> Function({
  required String alarmId,
  required int globalSlot,
  required int delayMs,
  Map<String, dynamic>? data,
});

typedef AlarmAuditScheduleForegroundResume
    = Future<ForegroundResumeAlarmScheduleResult> Function({
  required int rustWakeTimeMs,
  required String schedulerReason,
  required int globalSlot,
  required int slotTimeMs,
});

typedef AlarmAuditListActiveSlotWakeAlarmStates = Future<List<AlarmDebugState>>
    Function();

typedef AlarmAuditRecoveryRetryScheduler = void Function(
  Duration delay,
  void Function() callback,
);

class BlockProductionAlarmAuditService {
  BlockProductionAlarmAuditService._({
    Future<bool> Function()? initializeAlarmService,
    Future<bool> Function()? refreshPermissions,
    Future<bool> Function()? hasExactAlarmPermission,
    Future<bool> Function(String alarmId)? hasScheduledAlarm,
    Future<AlarmDebugState> Function(String alarmId)? getAlarmDebugState,
    AlarmAuditListActiveSlotWakeAlarmStates? listActiveSlotWakeAlarmStates,
    AlarmAuditScheduleAlarm? scheduleAlarm,
    AlarmAuditScheduleForegroundResume? scheduleForegroundResume,
    Future<AlarmAuditEpochSnapshot?> Function()? loadEpochSnapshot,
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
    Duration? slotWakeLead,
    Duration? foregroundResumeLead,
    List<Duration>? recoveryRetryDelays,
    AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry,
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
        _listActiveSlotWakeAlarmStates = listActiveSlotWakeAlarmStates ??
            PlatformAlarmService.instance.listActiveSlotWakeAlarmDebugStates,
        _scheduleAlarm =
            scheduleAlarm ?? PlatformAlarmService.instance.scheduleAlarm,
        _scheduleForegroundResume =
            scheduleForegroundResume ?? _scheduleDefaultForegroundResume,
        _loadEpochSnapshot = loadEpochSnapshot ?? _loadDefaultEpochSnapshot,
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
        _slotWakeLead = slotWakeLead ?? AppConfig.blockProductionWakeBeforeSlot,
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
            ((delay, callback) => Timer(delay, callback));

  @visibleForTesting
  BlockProductionAlarmAuditService.test({
    Future<bool> Function()? initializeAlarmService,
    Future<bool> Function()? refreshPermissions,
    Future<bool> Function()? hasExactAlarmPermission,
    Future<bool> Function(String alarmId)? hasScheduledAlarm,
    Future<AlarmDebugState> Function(String alarmId)? getAlarmDebugState,
    AlarmAuditListActiveSlotWakeAlarmStates? listActiveSlotWakeAlarmStates,
    AlarmAuditScheduleAlarm? scheduleAlarm,
    AlarmAuditScheduleForegroundResume? scheduleForegroundResume,
    Future<AlarmAuditEpochSnapshot?> Function()? loadEpochSnapshot,
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
    Duration? slotWakeLead,
    Duration? foregroundResumeLead,
    List<Duration>? recoveryRetryDelays,
    AlarmAuditRecoveryRetryScheduler? scheduleRecoveryRetry,
  }) : this._(
          initializeAlarmService: initializeAlarmService,
          refreshPermissions: refreshPermissions,
          hasExactAlarmPermission: hasExactAlarmPermission,
          hasScheduledAlarm: hasScheduledAlarm,
          getAlarmDebugState: getAlarmDebugState,
          listActiveSlotWakeAlarmStates: listActiveSlotWakeAlarmStates,
          scheduleAlarm: scheduleAlarm,
          scheduleForegroundResume: scheduleForegroundResume,
          loadEpochSnapshot: loadEpochSnapshot,
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
          slotWakeLead: slotWakeLead,
          foregroundResumeLead: foregroundResumeLead,
          recoveryRetryDelays: recoveryRetryDelays,
          scheduleRecoveryRetry: scheduleRecoveryRetry,
        );

  static final BlockProductionAlarmAuditService instance =
      BlockProductionAlarmAuditService._();

  final Future<bool> Function() _initializeAlarmService;
  final Future<bool> Function() _refreshPermissions;
  final Future<bool> Function() _hasExactAlarmPermission;
  final Future<AlarmDebugState> Function(String alarmId) _getAlarmDebugState;
  final AlarmAuditListActiveSlotWakeAlarmStates _listActiveSlotWakeAlarmStates;
  final AlarmAuditScheduleAlarm _scheduleAlarm;
  final AlarmAuditScheduleForegroundResume _scheduleForegroundResume;
  final Future<AlarmAuditEpochSnapshot?> Function() _loadEpochSnapshot;
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
  final Duration _slotWakeLead;
  final Duration _foregroundResumeLead;
  final List<Duration> _recoveryRetryDelays;
  final AlarmAuditRecoveryRetryScheduler _scheduleRecoveryRetry;

  Future<AlarmAuditResult>? _inFlight;
  bool _forceStopChecked = false;
  String? _pendingRecoveryReason;
  var _recoveryRetryAttempt = 0;
  var _recoveryRetryGeneration = 0;

  void auditBestEffort({required String reason}) {
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

  void handleNativeEvent(String eventType, Map<String, dynamic> eventData) {
    switch (eventType) {
      case 'android_alarm_recovery_requested':
        final reason = _stringValue(eventData['reason']) ?? 'native_recovery';
        _log.warn('Alarm audit received native recovery request', context: {
          'reason': reason,
          ...eventData,
        });
        _auditBestEffort(reason: reason, retryTransientRecovery: true);
        break;
      case 'android_exact_alarm_permission_granted':
        final stateChanged = eventData['stateChanged'] == true;
        final source = _stringValue(eventData['source']);
        if (stateChanged || source == 'permission_state_changed_broadcast') {
          _auditBestEffort(
            reason: 'exact_alarm_permission_granted',
            retryTransientRecovery: true,
          );
        }
        break;
    }
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
      _log.warn('Alarm recovery audit finished without retry', context: {
        'reason': reason,
        if (skippedReason != null) 'skipped_reason': skippedReason,
        'expected_slot_wake_count': result.expectedSlotWakeCount,
        'rescheduled_count': result.rescheduledCount,
        'fg_resume_status': result.fgResumeStatus,
      });
      _clearPendingRecovery(reason);
      return;
    }

    if (_recoveryRetryAttempt >= _recoveryRetryDelays.length) {
      _log.warn('Alarm recovery audit retries exhausted', context: {
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
    _log.warn('Alarm recovery audit will retry after transient skip', context: {
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
        skippedReason == 'no_won_slots';
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

      await _initializeAlarmService();
      await _refreshPermissions();

      final exactAlarmPermission = await _hasExactAlarmPermission();
      _reportStarted(
        reason: reason,
        exactAlarmPermission: exactAlarmPermission,
      );

      if (!exactAlarmPermission) {
        return _skip(
          reason,
          'no_exact_alarm_permission',
          fgResumeStatus: 'skipped:no_exact_alarm_permission',
        );
      }

      final counts = _AlarmAuditCounts();
      await _recoverActiveSlotWakeAlarms(
        reason: reason,
        counts: counts,
      );

      final nodeRunning = await _ensureNodeRunning();
      if (!nodeRunning) {
        return _skip(
          reason,
          'node_not_running',
          fgResumeStatus: 'skipped:node_not_running',
          counts: counts,
        );
      }

      final clockDriftMs = await _resolveClockDriftMs();
      if (clockDriftMs == null) {
        return _skip(
          reason,
          'clock_drift_unavailable',
          fgResumeStatus: 'skipped:clock_drift_unavailable',
          counts: counts,
        );
      }

      final epoch = await _loadEpochSnapshot();
      if (epoch == null) {
        return _skip(
          reason,
          'epoch_info_unavailable',
          fgResumeStatus: 'skipped:epoch_info_unavailable',
          counts: counts,
        );
      }

      if (epoch.wonSlots.isEmpty) {
        return _skip(
          reason,
          'no_won_slots',
          fgResumeStatus: 'no_won_slots',
          counts: counts,
        );
      }

      final auditNowMs = _nowMs();
      final built = _buildExpectedAlarms(
        epoch: epoch,
        clockDriftMs: clockDriftMs,
        nowMs: auditNowMs,
      );

      for (final alarm in built.pastSlotWakeAlarms) {
        await _auditPastSlotWakeAlarm(
          reason: reason,
          alarm: alarm,
          counts: counts,
        );
      }

      for (final alarm in built.futureSlotWakeAlarms) {
        await _auditFutureSlotWakeAlarm(
          reason: reason,
          alarm: alarm,
          counts: counts,
          clockDriftMs: clockDriftMs,
        );
      }

      final fgResumeStatus = await _auditForegroundResume(
        reason: reason,
        epoch: epoch,
        clockDriftMs: clockDriftMs,
      );

      _reportCompleted(
        reason: reason,
        expectedSlotWakeCount: built.futureSlotWakeAlarms.length,
        counts: counts,
        fgResumeStatus: fgResumeStatus,
      );

      return AlarmAuditResult(
        reason: reason,
        expectedSlotWakeCount: built.futureSlotWakeAlarms.length,
        presentCount: counts.presentCount,
        missingCount: counts.missingCount,
        rescheduledCount: counts.rescheduledCount,
        failedCount: counts.failedCount,
        fgResumeStatus: fgResumeStatus,
      );
    } catch (e, st) {
      _log.error('Alarm audit failed: $e', error: e, stackTrace: st);
      return _skip(
        reason,
        'audit_exception',
        failureReason: e.toString(),
        fgResumeStatus: 'skipped:audit_exception',
      );
    }
  }

  _ExpectedAlarmBuildResult _buildExpectedAlarms({
    required AlarmAuditEpochSnapshot epoch,
    required int clockDriftMs,
    required int nowMs,
  }) {
    final futureSlotWakeAlarms = <AlarmAuditExpectedAlarm>[];
    final pastSlotWakeAlarms = <AlarmAuditExpectedAlarm>[];
    final wakeLeadMs = _slotWakeLead.inMilliseconds;

    final wonSlots = List<AlarmAuditWonSlot>.of(epoch.wonSlots)
      ..sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));

    for (final wonSlot in wonSlots) {
      final slotTimeMs = _rustToLocalTimeMs(
        wonSlot.expectedTimeMs,
        clockDriftMs,
      );
      final alarmTimeMs = slotTimeMs - wakeLeadMs;
      final alarm = AlarmAuditExpectedAlarm(
        alarmId: 'slot_${wonSlot.globalSlot}',
        purpose: 'slot_wake',
        globalSlot: wonSlot.globalSlot,
        epoch: epoch.epoch,
        rustSlotTimeMs: wonSlot.expectedTimeMs,
        slotTimeMs: slotTimeMs,
        alarmTimeMs: alarmTimeMs,
        clockDriftMs: clockDriftMs,
        nodeTimeMsAtAudit: _lastNodeTimeMs(),
        systemTimeMsAtAudit: nowMs,
        clockDriftSampleAgeMs: _clockDriftSampleAgeMs(nowMs),
      );

      final target =
          alarmTimeMs <= nowMs ? pastSlotWakeAlarms : futureSlotWakeAlarms;
      target.add(alarm);
    }

    return _ExpectedAlarmBuildResult(
      futureSlotWakeAlarms: futureSlotWakeAlarms,
      pastSlotWakeAlarms: pastSlotWakeAlarms,
    );
  }

  Future<void> _auditFutureSlotWakeAlarm({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required _AlarmAuditCounts counts,
    required int clockDriftMs,
  }) async {
    final state = await _getAlarmDebugState(alarm.alarmId);
    if (state.pendingIntentExists) {
      counts.presentCount++;
      _reportPresent(reason: reason, alarm: alarm, state: state);
      return;
    }

    counts.missingCount++;
    final nowMs = _nowMs();
    final delayMs = alarm.alarmTimeMs - nowMs;
    if (delayMs <= 0) {
      await _auditPastSlotWakeAlarm(
        reason: reason,
        alarm: alarm,
        counts: counts,
        state: state,
        nowMs: nowMs,
      );
      return;
    }

    final success = await _scheduleAlarm(
      alarmId: alarm.alarmId,
      globalSlot: alarm.globalSlot,
      delayMs: delayMs,
      data: {
        'epoch': alarm.epoch,
        'slotTime': DateTime.fromMillisecondsSinceEpoch(alarm.slotTimeMs)
            .toIso8601String(),
        'slotTimeMs': alarm.slotTimeMs,
        'localSlotTimeMs': alarm.slotTimeMs,
        'rustSlotTimeMs': alarm.rustSlotTimeMs,
        'alarmTimeMs': alarm.alarmTimeMs,
        'purpose': alarm.purpose,
        'reason': 'alarm_audit:$reason',
        'nodeRunning': _isNodeRunning(),
        'rustWakeTimeMs': alarm.rustSlotTimeMs - _slotWakeLead.inMilliseconds,
        'localWakeTimeMs': alarm.alarmTimeMs,
        'clockDriftMs': clockDriftMs,
        ..._scheduleClockTelemetryData(nowMs),
      },
    );

    if (success) {
      counts.rescheduledCount++;
      _reportMissingRescheduled(
        reason: reason,
        alarm: alarm,
        scheduleSuccess: true,
        state: state,
      );
      return;
    }

    counts.failedCount++;
    _reportMissingRescheduleFailed(
      reason: reason,
      alarm: alarm,
      failureReason: 'platform_schedule_failed',
      state: state,
    );
  }

  Future<void> _auditPastSlotWakeAlarm({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required _AlarmAuditCounts counts,
    AlarmDebugState? state,
    int? nowMs,
  }) async {
    final debugState = state ?? await _getAlarmDebugState(alarm.alarmId);
    counts.pastSlotWakeCount++;

    final receiverEnteredAtMs = debugState.receiverEnteredAtMs;
    if (receiverEnteredAtMs != null) {
      final slotDeltaMs = receiverEnteredAtMs - alarm.slotTimeMs;
      final deliveryLatencyMs = receiverEnteredAtMs - alarm.alarmTimeMs;
      if (receiverEnteredAtMs > alarm.slotTimeMs) {
        counts.pastReceiverLateCount++;
        _reportPastReceiverLate(
          reason: reason,
          alarm: alarm,
          state: debugState,
          nowMs: nowMs ?? _nowMs(),
          deliveryLatencyMs: deliveryLatencyMs,
          slotDeltaMs: slotDeltaMs,
        );
        return;
      }

      counts.pastReceiverOnTimeCount++;
      _reportPastReceiverOnTime(
        reason: reason,
        alarm: alarm,
        state: debugState,
        nowMs: nowMs ?? _nowMs(),
        deliveryLatencyMs: deliveryLatencyMs,
        slotDeltaMs: slotDeltaMs,
      );
      return;
    }

    if (debugState.pendingIntentExists) {
      counts.pastPendingNoReceiverCount++;
      _reportPastPendingNoReceiver(
        reason: reason,
        alarm: alarm,
        state: debugState,
        nowMs: nowMs ?? _nowMs(),
      );
      return;
    }

    counts.pastMissingNoReceiverCount++;
    _reportPastMissingNoReceiver(
      reason: reason,
      alarm: alarm,
      state: debugState,
      nowMs: nowMs ?? _nowMs(),
    );
  }

  Future<void> _recoverActiveSlotWakeAlarms({
    required String reason,
    required _AlarmAuditCounts counts,
  }) async {
    List<AlarmDebugState> states;
    try {
      states = await _listActiveSlotWakeAlarmStates();
    } catch (e, st) {
      counts.activeSlotWakeFailedCount++;
      _log.warn('Active slot wake recovery failed to list states: $e');
      _log.debug('$st');
      _report('alarm_audit_active_slot_wake_recovery_failed', {
        'reason': reason,
        'failure_reason': 'list_states_exception',
        'error': e.toString(),
      });
      return;
    }

    if (states.isEmpty) {
      return;
    }

    final nowMs = _nowMs();
    for (final state in states) {
      counts.activeSlotWakeCount++;
      final globalSlot = state.globalSlot ??
          state.slotNumber ??
          _slotFromAlarmId(state.alarmId);
      final slotTimeMs = state.localSlotTimeMs ?? state.slotTimeMs;
      final alarmTimeMs =
          state.localWakeTimeMs ?? state.alarmTimeMs ?? state.triggerAtMs;

      if (globalSlot == null || slotTimeMs == null || alarmTimeMs == null) {
        continue;
      }

      if (slotTimeMs <= nowMs) {
        continue;
      }

      if (state.pendingIntentExists) {
        continue;
      }

      final delayMs = alarmTimeMs > nowMs ? alarmTimeMs - nowMs : 0;
      final success = await _scheduleAlarm(
        alarmId: state.alarmId,
        globalSlot: globalSlot,
        delayMs: delayMs,
        data: {
          if (state.epoch != null) 'epoch': state.epoch,
          'slotTimeMs': slotTimeMs,
          'localSlotTimeMs': slotTimeMs,
          if (state.rustSlotTimeMs != null)
            'rustSlotTimeMs': state.rustSlotTimeMs,
          'alarmTimeMs': alarmTimeMs,
          'purpose': 'slot_wake',
          'reason': 'active_slot_wake_recovery:$reason',
          'globalSlot': globalSlot,
          'nodeRunning': _isNodeRunning(),
          if (state.rustWakeTimeMs != null)
            'rustWakeTimeMs': state.rustWakeTimeMs,
          'localWakeTimeMs': alarmTimeMs,
          if (state.clockDriftMs != null) 'clockDriftMs': state.clockDriftMs,
          ..._scheduleClockTelemetryData(nowMs),
        },
      );

      if (success) {
        counts.activeSlotWakeRescheduledCount++;
        _report('alarm_audit_active_slot_wake_recovery_rescheduled', {
          'reason': reason,
          'global_slot': globalSlot,
          'slot_time_ms': slotTimeMs,
          'alarm_time_ms': alarmTimeMs,
          'delay_ms': delayMs,
          'alarm_wake_time_past': alarmTimeMs <= nowMs,
          if (alarmTimeMs <= nowMs) 'past_alarm_age_ms': nowMs - alarmTimeMs,
          ...state.telemetryDetails,
        });
        continue;
      }

      counts.activeSlotWakeFailedCount++;
      _report('alarm_audit_active_slot_wake_recovery_failed', {
        'reason': reason,
        'failure_reason': 'platform_schedule_failed',
        'global_slot': globalSlot,
        'slot_time_ms': slotTimeMs,
        'alarm_time_ms': alarmTimeMs,
        'delay_ms': delayMs,
        ...state.telemetryDetails,
      });
    }
  }

  int? _slotFromAlarmId(String alarmId) {
    if (!alarmId.startsWith('slot_')) {
      return null;
    }
    final slot = int.tryParse(alarmId.substring('slot_'.length));
    return slot != null && slot > 0 ? slot : null;
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
    if (nextWonSlot == null) {
      return 'no_future_won_slots';
    }

    final fgLeadMs = _foregroundResumeLead.inMilliseconds;
    if (nextWonSlot.slotTimeMs - nowMs <= fgLeadMs) {
      _report(
        'foreground_resume_not_scheduled_slot_too_close',
        {
          'reason': reason,
          'global_slot': nextWonSlot.globalSlot,
          'slot_time_ms': nextWonSlot.slotTimeMs,
          'now_ms': nowMs,
        },
      );
      return 'slot_too_close';
    }

    final alarm = AlarmAuditExpectedAlarm(
      alarmId: AndroidForegroundTaskController.foregroundResumeAlarmId,
      purpose: 'foreground_resume',
      globalSlot: nextWonSlot.globalSlot,
      epoch: epoch.epoch,
      rustSlotTimeMs: nextWonSlot.rustSlotTimeMs,
      slotTimeMs: nextWonSlot.slotTimeMs,
      alarmTimeMs: nextWonSlot.slotTimeMs - fgLeadMs,
      clockDriftMs: clockDriftMs,
      nodeTimeMsAtAudit: _lastNodeTimeMs(),
      systemTimeMsAtAudit: nowMs,
      clockDriftSampleAgeMs: _clockDriftSampleAgeMs(nowMs),
    );

    final state = await _getAlarmDebugState(alarm.alarmId);
    if (state.pendingIntentExists) {
      _reportPresent(reason: reason, alarm: alarm, state: state);
      _report(
        'foreground_resume_present',
        {
          'reason': reason,
          'global_slot': alarm.globalSlot,
          'alarm_time_ms': alarm.alarmTimeMs,
          'slot_time_ms': alarm.slotTimeMs,
          ...state.telemetryDetails,
        },
      );
      return 'present';
    }

    final schedulerReason = 'next_won_slot:${alarm.globalSlot}';
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
      _reportMissingRescheduled(
        reason: reason,
        alarm: scheduledAlarm,
        scheduleSuccess: true,
        state: state,
      );
      _report(
        'foreground_resume_recreated',
        {
          'reason': reason,
          'global_slot': scheduledAlarm.globalSlot,
          'alarm_time_ms': scheduledAlarm.alarmTimeMs,
          'slot_time_ms': scheduledAlarm.slotTimeMs,
          ...state.telemetryDetails,
        },
      );
      return 'recreated';
    }

    _reportMissingRescheduleFailed(
      reason: reason,
      alarm: scheduledAlarm,
      failureReason: result.failureReason ?? 'platform_schedule_failed',
      state: state,
    );
    return 'reschedule_failed';
  }

  _FutureWonSlot? _nextFutureWonSlot(
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
          return _FutureWonSlot(
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

  Map<String, dynamic> _scheduleClockTelemetryData(int systemTimeMs) {
    final nodeTimeMs = _lastNodeTimeMs();
    final clockDriftSampleAgeMs = _clockDriftSampleAgeMs(systemTimeMs);
    return {
      'systemTimeMsAtSchedule': systemTimeMs,
      if (nodeTimeMs != null) 'nodeTimeMsAtSchedule': nodeTimeMs,
      if (clockDriftSampleAgeMs != null)
        'clockDriftSampleAgeMs': clockDriftSampleAgeMs,
    };
  }

  int? _clockDriftSampleAgeMs(int systemTimeMs) {
    final sampleSystemTimeMs = _lastNodeClockSampleSystemTimeMs();
    if (sampleSystemTimeMs == null) return null;
    return systemTimeMs - sampleSystemTimeMs;
  }

  void _reportStarted({
    required String reason,
    required bool exactAlarmPermission,
  }) {
    _report(
      'alarm_audit_started',
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
    _AlarmAuditCounts? counts,
  }) {
    _log.info('Alarm audit skipped', context: {
      'reason': reason,
      'skipped_reason': skippedReason,
      if (failureReason != null) 'failure_reason': failureReason,
    });
    _report(
      'alarm_audit_skipped',
      {
        'reason': reason,
        'skipped_reason': skippedReason,
        if (failureReason != null) 'failure_reason': failureReason,
      },
    );
    final resolvedCounts = counts ?? _AlarmAuditCounts();
    _reportCompleted(
      reason: reason,
      expectedSlotWakeCount: 0,
      counts: resolvedCounts,
      fgResumeStatus: fgResumeStatus,
    );

    return AlarmAuditResult(
      reason: reason,
      skippedReason: skippedReason,
      expectedSlotWakeCount: 0,
      presentCount: resolvedCounts.presentCount,
      missingCount: resolvedCounts.missingCount,
      rescheduledCount: resolvedCounts.rescheduledCount,
      failedCount: resolvedCounts.failedCount,
      fgResumeStatus: fgResumeStatus,
    );
  }

  void _reportCompleted({
    required String reason,
    required int expectedSlotWakeCount,
    required _AlarmAuditCounts counts,
    required String fgResumeStatus,
  }) {
    _log.info('Alarm audit completed', context: {
      'reason': reason,
      'expected_slot_wake_count': expectedSlotWakeCount,
      'present_count': counts.presentCount,
      'missing_count': counts.missingCount,
      'rescheduled_count': counts.rescheduledCount,
      'failed_count': counts.failedCount,
      'past_slot_wake_count': counts.pastSlotWakeCount,
      'past_receiver_on_time_count': counts.pastReceiverOnTimeCount,
      'past_receiver_late_count': counts.pastReceiverLateCount,
      'past_pending_no_receiver_count': counts.pastPendingNoReceiverCount,
      'past_missing_no_receiver_count': counts.pastMissingNoReceiverCount,
      'active_slot_wake_count': counts.activeSlotWakeCount,
      'active_slot_wake_rescheduled_count':
          counts.activeSlotWakeRescheduledCount,
      'active_slot_wake_failed_count': counts.activeSlotWakeFailedCount,
      'fg_resume_status': fgResumeStatus,
    });
    _report(
      'alarm_audit_completed',
      {
        'reason': reason,
        'expected_slot_wake_count': expectedSlotWakeCount,
        'present_count': counts.presentCount,
        'missing_count': counts.missingCount,
        'rescheduled_count': counts.rescheduledCount,
        'failed_count': counts.failedCount,
        'past_slot_wake_count': counts.pastSlotWakeCount,
        'past_receiver_on_time_count': counts.pastReceiverOnTimeCount,
        'past_receiver_late_count': counts.pastReceiverLateCount,
        'past_pending_no_receiver_count': counts.pastPendingNoReceiverCount,
        'past_missing_no_receiver_count': counts.pastMissingNoReceiverCount,
        'active_slot_wake_count': counts.activeSlotWakeCount,
        'active_slot_wake_rescheduled_count':
            counts.activeSlotWakeRescheduledCount,
        'active_slot_wake_failed_count': counts.activeSlotWakeFailedCount,
        'fg_resume_status': fgResumeStatus,
      },
    );
  }

  void _reportPresent({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    AlarmDebugState? state,
  }) {
    _report('alarm_audit_present', {
      'reason': reason,
      ...alarm.telemetryDetails,
      if (state != null) ...state.telemetryDetails,
    });
  }

  void _reportMissingRescheduled({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required bool scheduleSuccess,
    AlarmDebugState? state,
  }) {
    _report('alarm_audit_missing_rescheduled', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'schedule_success': scheduleSuccess,
      if (state != null) ...state.telemetryDetails,
    });
  }

  void _reportMissingRescheduleFailed({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required String failureReason,
    AlarmDebugState? state,
  }) {
    _report('alarm_audit_missing_reschedule_failed', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'failure_reason': failureReason,
      if (state != null) ...state.telemetryDetails,
    });
  }

  void _reportPastReceiverOnTime({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required AlarmDebugState state,
    required int nowMs,
    required int deliveryLatencyMs,
    required int slotDeltaMs,
  }) {
    _report('alarm_audit_past_receiver_on_time', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'now_ms': nowMs,
      'delivery_latency_ms': deliveryLatencyMs,
      'slot_delta_ms': slotDeltaMs,
      ...state.telemetryDetails,
    });
  }

  void _reportPastReceiverLate({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required AlarmDebugState state,
    required int nowMs,
    required int deliveryLatencyMs,
    required int slotDeltaMs,
  }) {
    _report('alarm_audit_past_receiver_late', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'now_ms': nowMs,
      'delivery_latency_ms': deliveryLatencyMs,
      'slot_delta_ms': slotDeltaMs,
      ...state.telemetryDetails,
    });
  }

  void _reportPastPendingNoReceiver({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required AlarmDebugState state,
    required int nowMs,
  }) {
    _report('alarm_audit_past_pending_no_receiver', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'now_ms': nowMs,
      'past_alarm_age_ms': nowMs - alarm.alarmTimeMs,
      ...state.telemetryDetails,
    });
  }

  void _reportPastMissingNoReceiver({
    required String reason,
    required AlarmAuditExpectedAlarm alarm,
    required AlarmDebugState state,
    required int nowMs,
  }) {
    _report('alarm_audit_past_missing_no_receiver', {
      'reason': reason,
      ...alarm.telemetryDetails,
      'now_ms': nowMs,
      'past_alarm_age_ms': nowMs - alarm.alarmTimeMs,
      ...state.telemetryDetails,
    });
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
    if (RustBackendService.instance.isRunning) {
      return true;
    }

    return false;
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
    required this.wonSlots,
  });

  final int epoch;
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

  Map<String, dynamic> get telemetryDetails => {
        'alarm_id': alarmId,
        'purpose': purpose,
        'global_slot': globalSlot,
        'epoch': epoch,
        'alarm_time_ms': alarmTimeMs,
        'slot_time_ms': slotTimeMs,
        'rust_slot_time_ms': rustSlotTimeMs,
        'local_slot_time_ms': slotTimeMs,
        'clock_drift_ms': clockDriftMs,
        if (nodeTimeMsAtAudit != null) 'audit_node_time_ms': nodeTimeMsAtAudit,
        if (systemTimeMsAtAudit != null)
          'audit_system_time_ms': systemTimeMsAtAudit,
        if (clockDriftSampleAgeMs != null)
          'audit_clock_drift_sample_age_ms': clockDriftSampleAgeMs,
      };

  AlarmAuditExpectedAlarm copyWith({
    int? alarmTimeMs,
  }) {
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
}

class AlarmAuditResult {
  const AlarmAuditResult({
    required this.reason,
    required this.expectedSlotWakeCount,
    required this.presentCount,
    required this.missingCount,
    required this.rescheduledCount,
    required this.failedCount,
    required this.fgResumeStatus,
    this.skippedReason,
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

class _ExpectedAlarmBuildResult {
  const _ExpectedAlarmBuildResult({
    required this.futureSlotWakeAlarms,
    required this.pastSlotWakeAlarms,
  });

  final List<AlarmAuditExpectedAlarm> futureSlotWakeAlarms;
  final List<AlarmAuditExpectedAlarm> pastSlotWakeAlarms;
}

class _AlarmAuditCounts {
  _AlarmAuditCounts();

  int presentCount = 0;
  int missingCount = 0;
  int rescheduledCount = 0;
  int failedCount = 0;
  int pastSlotWakeCount = 0;
  int pastReceiverOnTimeCount = 0;
  int pastReceiverLateCount = 0;
  int pastPendingNoReceiverCount = 0;
  int pastMissingNoReceiverCount = 0;
  int activeSlotWakeCount = 0;
  int activeSlotWakeRescheduledCount = 0;
  int activeSlotWakeFailedCount = 0;
}

class _FutureWonSlot {
  const _FutureWonSlot({
    required this.globalSlot,
    required this.rustSlotTimeMs,
    required this.slotTimeMs,
  });

  final int globalSlot;
  final int rustSlotTimeMs;
  final int slotTimeMs;
}
