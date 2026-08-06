import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:crypto_mobile_app/core/models/vrf_status.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';

final _log = LoggingService.instance.withTag('usernode/AndroidForegroundTask');

typedef MonitoringStoppedCallback = Future<void> Function(
  NodeRuntimeAuthority authority,
);

class AndroidForegroundTaskController {
  AndroidForegroundTaskController._({
    bool Function()? isAndroid,
    NodeRuntimeAuthority? monitoringAuthority,
  })  : _isAndroid = isAndroid ?? (() => Platform.isAndroid),
        _monitoringAuthority = monitoringAuthority;

  @visibleForTesting
  AndroidForegroundTaskController.test({
    required bool Function() isAndroid,
    NodeRuntimeAuthority? monitoringAuthority,
  }) : this._(
          isAndroid: isAndroid,
          monitoringAuthority: monitoringAuthority,
        );

  static final AndroidForegroundTaskController instance =
      AndroidForegroundTaskController._();

  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _alarmEventDedupWindow = Duration(seconds: 10);
  static const foregroundResumeLead = Duration(minutes: 4);
  static const foregroundResumeAlarmId = 'fg_resume';

  Timer? _pollTimer;
  Future<void>? _activePoll;
  bool _initialized = false;
  bool _wakelockHeld = false;
  NodeRuntimeAuthority? _monitoringAuthority;
  AccountPublicKey? _cachedOurPubKey;
  ({int height, DateTime since})? _awaitingOtherProducerState;
  String? _alarmRecoveryInFlightKey;
  String? _lastHandledAlarmKey;
  DateTime? _lastHandledAlarmAt;
  MonitoringStoppedCallback? _onMonitoringStopped;
  final bool Function() _isAndroid;

  void setMonitoringStoppedCallback(MonitoringStoppedCallback callback) {
    _onMonitoringStopped = callback;
  }

  Future<void> initialize() async {
    if (!_isAndroid()) return;
    if (_initialized) return;

    WidgetsFlutterBinding.ensureInitialized();

    // Request notification permission on Android 13+ so the foreground
    // notification is visible. In headless mode (no Activity), we can only
    // check the status, not request it.
    try {
      final notificationStatus = await Permission.notification.request();
      _log.info('Notification permission status: $notificationStatus');
    } on PlatformException catch (e) {
      // In headless mode, PermissionHandler cannot detect an Activity.
      // Just check the status instead of requesting.
      if (e.code == 'PermissionHandler.PermissionManager' &&
          e.message?.contains('Unable to detect current Android Activity') ==
              true) {
        _log.debug(
            'Running in headless mode, checking notification permission status instead of requesting');
        try {
          final status = await Permission.notification.status;
          _log.info('Notification permission status (headless): $status');
        } catch (statusError) {
          _log.warn(
              'Could not check notification permission status: $statusError');
        }
      } else {
        // Re-throw if it's a different error
        rethrow;
      }
    } catch (e) {
      _log.warn('Error handling notification permission: $e');
    }
    _recordRuntimeContextChanged('permissions_changed');

    _initialized = true;
    _log.info('AndroidForegroundTask initialized');
  }

  Future<void> onNodeStarted({required NodeRuntimeAuthority authority}) async {
    if (!_isAndroid()) return;
    _adoptMonitoringAuthority(authority);
    if (AppSleepStateStore.isSleeping) {
      _log.info('Skipping Android monitoring start while app sleep is active');
      return;
    }
    await startMonitoring(reason: 'node_started', authority: authority);
  }

  Future<bool> startMonitoring({
    String reason = 'manual',
    bool allowWhileSleeping = false,
    NodeRuntimeAuthority? authority,
  }) async {
    if (!_isAndroid()) return false;
    if (AppSleepStateStore.isSleeping && !allowWhileSleeping) {
      _log.info(
        'Skipping Android monitoring start while app sleep is active',
        context: {'reason': reason},
      );
      return false;
    }
    await initialize();

    // Lifecycle authority belongs to NodeLifecycleCoordinator. Monitoring is
    // only a consumer of an already-authorized runtime.
    if (!RustBackendService.instance.isRunning) {
      _log.error('Cannot start monitoring: authorized node is not running');
      return false;
    }

    final monitoringAuthority = authority ??
        _monitoringAuthority ??
        RustBackendService.instance.runtimeAuthority;
    if (monitoringAuthority == null) {
      _log.error('Cannot start monitoring: runtime authority is unavailable');
      return false;
    }

    final result = await PlatformAlarmService.instance.startForegroundService(
      title: 'Usernode',
      message: 'Evaluating VRF slots',
      globalSlot: 0,
      authority: monitoringAuthority,
    );
    _log.info('Foreground service start result: $result');
    if (!result) {
      _log.error('Cannot start monitoring: authority was superseded');
      return false;
    }

    _adoptMonitoringAuthority(monitoringAuthority);
    _wakelockHeld = true;
    _startPollTimer();
    return true;
  }

  Future<void> stopMonitoring({
    String reason = 'stopped',
    NodeRuntimeAuthority? authority,
  }) async {
    if (!_isAndroid()) return;
    final monitoringAuthority = authority ?? _monitoringAuthority;
    if (authority != null &&
        _monitoringAuthority != null &&
        _monitoringAuthority != authority) {
      _log.info('Ignoring monitoring stop from a superseded authority');
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = null;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppMinimized = lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached;
    if (isAppMinimized) {
      await RustBackendService.instance.pauseNode();
    } else {
      _log.info(
          'Activity is resumed; skipping node pause on stopMonitoring ($reason)');
    }
    if (monitoringAuthority != null) {
      await PlatformAlarmService.instance.stopForegroundService(
        authority: monitoringAuthority,
      );
      if (_monitoringAuthority == monitoringAuthority) {
        _adoptMonitoringAuthority(null);
      }
    }
    _wakelockHeld = false;
    final onMonitoringStopped = _onMonitoringStopped;
    if (monitoringAuthority != null && onMonitoringStopped != null) {
      unawaited(onMonitoringStopped(monitoringAuthority));
    }
  }

  void _startPollTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _startPoll();
    });
    _startPoll();
  }

  void _startPoll() {
    if (_activePoll != null) return;
    final authority = _monitoringAuthority;
    if (authority == null) {
      _log.warn('Skipping VRF poll: monitoring authority is unavailable');
      return;
    }
    final poll = _pollVrf(authority);
    _activePoll = poll;
    unawaited(poll.whenComplete(() {
      if (identical(_activePoll, poll)) _activePoll = null;
    }));
  }

  Future<void> handleAlarmFire({
    String reason = 'alarm',
    String? alarmKey,
    bool allowWhileSleeping = false,
  }) async {
    if (AppSleepStateStore.isSleeping && !allowWhileSleeping) {
      _log.info(
        'Ignoring alarm-fired monitoring start while app sleep is active',
        context: {'reason': reason},
      );
      return;
    }

    if (alarmKey != null) {
      final now = DateTime.now();
      if (_alarmRecoveryInFlightKey == alarmKey) {
        _log.info(
          'Ignoring duplicate alarm event while recovery is in flight',
          context: {'reason': reason, 'alarm_key': alarmKey},
        );
        return;
      }

      final lastHandledAt = _lastHandledAlarmAt;
      if (_lastHandledAlarmKey == alarmKey &&
          lastHandledAt != null &&
          now.difference(lastHandledAt) <= _alarmEventDedupWindow) {
        _log.info(
          'Ignoring duplicate alarm event that was already handled',
          context: {'reason': reason, 'alarm_key': alarmKey},
        );
        return;
      }

      _alarmRecoveryInFlightKey = alarmKey;
    }

    _log.info('Alarm fired, restarting foreground task ($reason)');
    try {
      await startMonitoring(
        reason: reason,
        allowWhileSleeping: allowWhileSleeping,
      );
    } finally {
      if (alarmKey != null && _alarmRecoveryInFlightKey == alarmKey) {
        _alarmRecoveryInFlightKey = null;
        _lastHandledAlarmKey = alarmKey;
        _lastHandledAlarmAt = DateTime.now();
      }
    }
  }

  Future<void> resetForAppRestart() async {
    if (!_isAndroid()) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _activePoll;
    _activePoll = null;
    _initialized = false;
    _wakelockHeld = false;
    _adoptMonitoringAuthority(null);
    _cachedOurPubKey = null;
    _awaitingOtherProducerState = null;
    _alarmRecoveryInFlightKey = null;
    _lastHandledAlarmKey = null;
    _lastHandledAlarmAt = null;
  }

  Future<void> _pollVrf(NodeRuntimeAuthority authority) async {
    try {
      final info = await RustBackendService.instance.getEpochInfo();
      if (!_isCurrentMonitoringAuthority(authority)) return;
      if (info == null) {
        _log.warn('VRF poll: epoch info unavailable');
        return;
      }

      final clockDriftMs =
          await RustBackendService.instance.resolveNodeClockDriftMs();
      if (!_isCurrentMonitoringAuthority(authority)) return;
      if (clockDriftMs == null) {
        _log.warn('VRF poll: node clock drift unavailable');
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final rustNowMs = RustBackendService.instance.rustTimeMsFromLocalTimeMs(
        nowMs,
        clockDriftMs: clockDriftMs,
      );
      final nextWon = _nextWonSlot(info.wonSlots, rustNowMs);

      if (nextWon != null) {
        final rustSlotTimeMs = nextWon.expectedTimeMs.toInt();
        final localSlotTimeMs =
            RustBackendService.instance.localTimeMsFromRustTimeMs(
          rustSlotTimeMs,
          clockDriftMs: clockDriftMs,
        );
        final diffMs = localSlotTimeMs - nowMs;

        if (diffMs > foregroundResumeLead.inMilliseconds) {
          await _scheduleResume(
            rustSlotTimeMs - foregroundResumeLead.inMilliseconds,
            'next_won_slot:${nextWon.globalSlot}',
            targetGlobalSlot: nextWon.globalSlot,
            targetRustSlotTimeMs: rustSlotTimeMs,
            targetSlotTimeMs: localSlotTimeMs,
            authority: authority,
          );
        } else {
          _log.info(
            'Next won slot ${nextWon.globalSlot} is too close, keeping foreground running',
          );
        }
        return;
      }

      if (info.vrfStatus != VRFStatus.complete) {
        _log.debug(
            'VRF poll: status=${info.vrfStatus.displayName}, continuing');
        return;
      }

      final epochEndRustTimeMs = await resolveEpochEndTimeMs(info.currentEpoch);
      if (!_isCurrentMonitoringAuthority(authority)) return;
      if (epochEndRustTimeMs == null) {
        _log.warn('VRF poll: could not compute epoch end');
        return;
      }

      final localEpochEndTimeMs =
          RustBackendService.instance.localTimeMsFromRustTimeMs(
        epochEndRustTimeMs,
        clockDriftMs: clockDriftMs,
      );
      final untilEndMs = localEpochEndTimeMs - nowMs;
      if (untilEndMs > foregroundResumeLead.inMilliseconds) {
        await _scheduleResume(
          epochEndRustTimeMs - foregroundResumeLead.inMilliseconds,
          'epoch_end_${info.currentEpoch}',
          authority: authority,
        );
      } else {
        _log.info('Epoch end is too close, keeping foreground until end');
      }
    } catch (e, st) {
      _log.error('VRF poll failed', error: e, stackTrace: st);
    }
  }

  Future<bool> _shouldHoldForOtherProducerBlock({
    NodeRuntimeAuthority? authority,
    bool doubleCheck = true,
  }) async {
    if (authority != null && !_isCurrentMonitoringAuthority(authority)) {
      return false;
    }
    try {
      if (_cachedOurPubKey == null) {
        final bpStatus =
            await RustBackendService.instance.getBlockProducerStatus();
        if (authority != null && !_isCurrentMonitoringAuthority(authority)) {
          return false;
        }
        _cachedOurPubKey = bpStatus?.blockProducer?.pubKey;
      }
      if (_cachedOurPubKey == null) {
        _awaitingOtherProducerState = null;
        return false;
      }

      if (_awaitingOtherProducerState == null) {
        final ownBlocks = await RustBackendService.instance.listBlockchain(
          limit: 1,
          fromTip: true,
          blockProducer: _cachedOurPubKey,
        );
        if (authority != null && !_isCurrentMonitoringAuthority(authority)) {
          return false;
        }
        final ownBlock = (ownBlocks?.items.isNotEmpty ?? false)
            ? ownBlocks!.items.first
            : null;
        if (ownBlock == null) {
          _awaitingOtherProducerState = null;
          return false;
        }
        _awaitingOtherProducerState =
            (height: ownBlock.height, since: DateTime.now());
      }

      if (_awaitingOtherProducerState == null) {
        return false;
      }

      final waitingSince = _awaitingOtherProducerState!.since;
      if (DateTime.now().difference(waitingSince) >
          const Duration(seconds: 30)) {
        _log.info(
          'Waited 30 seconds for another producer block after height ${_awaitingOtherProducerState!.height}; releasing',
        );
        _awaitingOtherProducerState = null;
        return false;
      }

      final recentBlocks = await RustBackendService.instance.listBlockchain(
        limit: 1,
        fromTip: true,
      );
      if (authority != null && !_isCurrentMonitoringAuthority(authority)) {
        return false;
      }
      final items = recentBlocks?.items ?? const [];
      final ourPubKeyStr = _cachedOurPubKey.toString();
      final hasOtherAfter = items.any((block) =>
          block.height > _awaitingOtherProducerState!.height &&
          block.producerPubkey.toString() != ourPubKeyStr);

      if (hasOtherAfter) {
        if (doubleCheck) {
          return await _shouldHoldForOtherProducerBlock(
            authority: authority,
            doubleCheck: false,
          );
        }
        _awaitingOtherProducerState = null;
        return false;
      }

      return true;
    } catch (e, st) {
      _log.warn(
        'Failed to check post-production block status: $e',
      );
      _log.debug('$st');
      if (authority != null && !_isCurrentMonitoringAuthority(authority)) {
        return false;
      }
      return _awaitingOtherProducerState != null;
    }
  }

  Future<void> _scheduleResume(
    int rustWakeTimeMs,
    String reason, {
    int? targetGlobalSlot,
    int? targetRustSlotTimeMs,
    int? targetSlotTimeMs,
    required NodeRuntimeAuthority authority,
  }) async {
    await scheduleResumeAlarm(
      rustWakeTimeMs: rustWakeTimeMs,
      reason: reason,
      targetGlobalSlot: targetGlobalSlot,
      targetRustSlotTimeMs: targetRustSlotTimeMs,
      targetSlotTimeMs: targetSlotTimeMs,
      stopMonitoringAfterSchedule: true,
      authority: authority,
    );
  }

  Future<ForegroundResumeAlarmScheduleResult> scheduleResumeAlarm({
    required int rustWakeTimeMs,
    required String reason,
    int? targetGlobalSlot,
    int? targetRustSlotTimeMs,
    int? targetSlotTimeMs,
    bool stopMonitoringAfterSchedule = false,
    NodeRuntimeAuthority? authority,
  }) async {
    final schedulingAuthority = authority ?? _monitoringAuthority;
    if (_isAndroid() && schedulingAuthority == null) {
      _log.warn('Skipping resume alarm: monitoring authority is unavailable');
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'runtime_authority_unavailable',
      );
    }
    if (_isAndroid() && !_isCurrentMonitoringAuthority(schedulingAuthority!)) {
      _log.info('Skipping resume alarm from a superseded authority');
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'runtime_authority_superseded',
      );
    }

    if (await _shouldHoldForOtherProducerBlock(
      authority: schedulingAuthority,
    )) {
      final height = _awaitingOtherProducerState?.height;
      _log.info(
        'Keeping wakelock: waiting for another producer block after height ${height ?? 'unknown'}',
      );
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'holding_for_other_producer_block',
      );
    }
    if (_isAndroid() && !_isCurrentMonitoringAuthority(schedulingAuthority!)) {
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'runtime_authority_superseded',
      );
    }

    final clockDriftMs =
        await RustBackendService.instance.resolveNodeClockDriftMs();
    if (_isAndroid() && !_isCurrentMonitoringAuthority(schedulingAuthority!)) {
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'runtime_authority_superseded',
      );
    }
    if (clockDriftMs == null) {
      _log.warn('Skipping resume alarm: node clock drift unavailable');
      return const ForegroundResumeAlarmScheduleResult(
        success: false,
        failureReason: 'clock_drift_unavailable',
      );
    }
    final localWakeTimeMs =
        RustBackendService.instance.localTimeMsFromRustTimeMs(
      rustWakeTimeMs,
      clockDriftMs: clockDriftMs,
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final sampleSystemTimeMs =
        RustBackendService.instance.lastNodeClockSampleSystemTimeMs;
    final clockDriftSampleAgeMs =
        sampleSystemTimeMs == null ? null : nowMs - sampleSystemTimeMs;
    final delayMs = localWakeTimeMs - nowMs;
    final success = await PlatformAlarmService.instance.scheduleAlarm(
      alarmId: foregroundResumeAlarmId,
      delayMs: delayMs,
      globalSlot: targetGlobalSlot ?? 0,
      authority: schedulingAuthority,
      data: {
        'reason': reason,
        'nodeRunning': RustBackendService.instance.isRunning,
        'rustWakeTimeMs': rustWakeTimeMs,
        'localWakeTimeMs': localWakeTimeMs,
        'clockDriftMs': clockDriftMs,
        'purpose': 'foreground_resume',
        'systemTimeMsAtSchedule': nowMs,
        if (RustBackendService.instance.lastNodeTimeMs != null)
          'nodeTimeMsAtSchedule': RustBackendService.instance.lastNodeTimeMs,
        if (clockDriftSampleAgeMs != null)
          'clockDriftSampleAgeMs': clockDriftSampleAgeMs,
        if (targetGlobalSlot != null) 'globalSlot': targetGlobalSlot,
        if (targetRustSlotTimeMs != null)
          'rustSlotTimeMs': targetRustSlotTimeMs,
        if (targetSlotTimeMs != null) 'slotTimeMs': targetSlotTimeMs,
        if (targetSlotTimeMs != null) 'localSlotTimeMs': targetSlotTimeMs,
      },
    );

    final localWakeTime = DateTime.fromMillisecondsSinceEpoch(localWakeTimeMs);
    _log.info(
      'Scheduled resume alarm at $localWakeTime for $reason '
      '(success=$success, rustWakeTimeMs=$rustWakeTimeMs, '
      'clockDriftMs=$clockDriftMs)',
    );
    if (success && stopMonitoringAfterSchedule) {
      await stopMonitoring(
        reason: reason,
        authority: schedulingAuthority,
      );
    }

    return ForegroundResumeAlarmScheduleResult(
      success: success,
      alarmTimeMs: localWakeTimeMs,
      delayMs: delayMs,
      clockDriftMs: clockDriftMs,
      failureReason: success ? null : 'platform_schedule_failed',
    );
  }

  RpcEpochWonSlot? _nextWonSlot(List<RpcEpochWonSlot> slots, int rustNowMs) {
    final futureSlots = slots
        .where((s) => s.expectedTimeMs.toInt() + 5000 > rustNowMs)
        .toList()
      ..sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));
    if (futureSlots.isEmpty) return null;
    return futureSlots.first;
  }

  Future<int?> resolveEpochEndTimeMs(int epoch) async {
    try {
      final status = await RustBackendService.instance.getStatus(
        includeVrfDetails: false,
      );
      final slotsInEpoch = status?.node.slotsInEpoch;
      if (slotsInEpoch == null || slotsInEpoch <= 0) return null;

      final slotResp = await RustBackendService.instance.getSlotTime(
        epoch: epoch,
        slot: slotsInEpoch - 1,
      );
      final timestampMs = slotResp?.timestampMs?.toInt();
      if (timestampMs == null) return null;
      return timestampMs;
    } catch (_) {
      return null;
    }
  }

  Future<bool> isForegroundServiceRunning() async {
    if (!_isAndroid()) return false;
    return await PlatformAlarmService.instance.isForegroundServiceRunning();
  }

  /// Handle native alarm events (from AlarmReceiver via PlatformAlarmService)
  Future<void> handleNativeEvent(
    String eventType,
    Map<String, dynamic> data,
  ) async {
    if (!_isAndroid()) return;
    switch (eventType) {
      case 'android_alarm_fired':
        await _handleAlarmFiredEvent(data);
        return;
      case 'android_alarm_recovery_requested':
        await startMonitoring(
          reason: 'native_recovery',
          allowWhileSleeping: true,
        );
        return;
    }
  }

  Future<void> _handleAlarmFiredEvent(Map<String, dynamic> data) async {
    var allowWhileSleeping = false;
    if (AppSleepStateStore.isSleeping) {
      final nativeWakelockHeld =
          await PlatformAlarmService.instance.isWakelockHeld();
      if (!nativeWakelockHeld) {
        _log.info('Ignoring native alarm event while app sleep is active');
        return;
      }

      allowWhileSleeping = true;
      _log.info(
        'Processing native alarm event while app sleep is active because the native wakelock is already held',
      );
    }

    final alarmId = data['alarmId'] as String? ?? '';
    if (alarmId == foregroundResumeAlarmId) {
      final alarmKey = _alarmEventKey(data);
      await handleAlarmFire(
        reason: 'alarm_resume',
        alarmKey: alarmKey,
        allowWhileSleeping: allowWhileSleeping,
      );
    }
  }

  String _alarmEventKey(Map<String, dynamic> data) {
    final alarmId = data['alarmId'] as String? ?? 'unknown_alarm';
    final alarmTimeMs = _intFromDynamic(data['alarmTimeMs']);
    if (alarmTimeMs != null) {
      return '$alarmId:$alarmTimeMs';
    }

    final globalSlot = _intFromDynamic(data['globalSlot']) ??
        _intFromDynamic(data['global_slot']) ??
        _intFromDynamic(data['slotNumber']);
    if (globalSlot != null) {
      return '$alarmId:slot:$globalSlot';
    }

    return alarmId;
  }

  int? _intFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<bool> isWakelockHeld() async {
    if (!_isAndroid()) return false;
    if (_wakelockHeld) return true;
    try {
      return await PlatformAlarmService.instance.isWakelockHeld();
    } catch (_) {
      return false;
    }
  }

  bool isWakelockHeldSync() {
    if (!_isAndroid()) return false;
    return _wakelockHeld;
  }

  bool _isCurrentMonitoringAuthority(NodeRuntimeAuthority authority) =>
      _monitoringAuthority == authority;

  void _adoptMonitoringAuthority(NodeRuntimeAuthority? authority) {
    final current = _monitoringAuthority;
    final unchanged = current == null
        ? authority == null
        : authority != null && current == authority;
    if (!unchanged) {
      _cachedOurPubKey = null;
      _awaitingOtherProducerState = null;
    }
    _monitoringAuthority = authority;
  }

  void _recordRuntimeContextChanged(String reason) {
    unawaited(
      ObservabilityReportingService.instance.reportRuntimeMobileContextSnapshot(
        reason: reason,
      ),
    );
  }
}

class ForegroundResumeAlarmScheduleResult {
  const ForegroundResumeAlarmScheduleResult({
    required this.success,
    this.alarmTimeMs,
    this.delayMs,
    this.clockDriftMs,
    this.failureReason,
  });

  final bool success;
  final int? alarmTimeMs;
  final int? delayMs;
  final int? clockDriftMs;
  final String? failureReason;
}

// Foreground service lifecycle is handled natively via PlatformAlarmService.
