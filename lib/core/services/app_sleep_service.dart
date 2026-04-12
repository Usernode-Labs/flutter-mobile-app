import 'dart:async';
import 'dart:io';

import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/ios_foreground_keepalive_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/slot_monitor_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_sleep_state_store.dart';

final _log = LoggingService.instance.withTag('usernode/AppSleep');

enum AppSleepReason {
  idleTimeout,
  lifecycleInactive,
  lifecyclePaused,
  lifecycleHidden,
  lifecycleDetached,
}

@immutable
class AppSleepSnapshot {
  const AppSleepSnapshot({
    required this.isSleeping,
    required this.lifecycleState,
    required this.lastInteractionAt,
    this.scheduledWakeAt,
    this.scheduledWakeSlotNumber,
    this.reason,
  });

  final bool isSleeping;
  final AppLifecycleState lifecycleState;
  final DateTime lastInteractionAt;
  final DateTime? scheduledWakeAt;
  final int? scheduledWakeSlotNumber;
  final AppSleepReason? reason;

  AppSleepSnapshot copyWith({
    bool? isSleeping,
    AppLifecycleState? lifecycleState,
    DateTime? lastInteractionAt,
    Object? scheduledWakeAt = _scheduledWakeAtSentinel,
    Object? scheduledWakeSlotNumber = _scheduledWakeSlotSentinel,
    Object? reason = _reasonSentinel,
  }) {
    return AppSleepSnapshot(
      isSleeping: isSleeping ?? this.isSleeping,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      scheduledWakeAt: identical(scheduledWakeAt, _scheduledWakeAtSentinel)
          ? this.scheduledWakeAt
          : scheduledWakeAt as DateTime?,
      scheduledWakeSlotNumber:
          identical(scheduledWakeSlotNumber, _scheduledWakeSlotSentinel)
              ? this.scheduledWakeSlotNumber
              : scheduledWakeSlotNumber as int?,
      reason: identical(reason, _reasonSentinel)
          ? this.reason
          : reason as AppSleepReason?,
    );
  }
}

const _reasonSentinel = Object();
const _scheduledWakeAtSentinel = Object();
const _scheduledWakeSlotSentinel = Object();

class AppSleepService extends ChangeNotifier {
  AppSleepService._()
      : _idleTimeout = defaultIdleTimeout,
        _inactiveWakelockRetryInterval = defaultInactiveWakelockRetryInterval,
        _sleepOverride = null,
        _wakeOverride = null,
        _persistSleepingOverride = null,
        _isWakelockHeldOverride = null;

  @visibleForTesting
  AppSleepService.forTest({
    Duration idleTimeout = defaultIdleTimeout,
    Duration inactiveWakelockRetryInterval =
        defaultInactiveWakelockRetryInterval,
    Future<void> Function(AppSleepReason reason)? onSleep,
    Future<void> Function(String reason)? onWake,
    Future<void> Function(bool value)? persistSleepState,
    Future<bool> Function()? isWakelockHeld,
    AppLifecycleState initialLifecycleState = AppLifecycleState.resumed,
  })  : _idleTimeout = idleTimeout,
        _inactiveWakelockRetryInterval = inactiveWakelockRetryInterval,
        _sleepOverride = onSleep,
        _wakeOverride = onWake,
        _persistSleepingOverride = persistSleepState,
        _isWakelockHeldOverride = isWakelockHeld {
    _snapshot = AppSleepSnapshot(
      isSleeping: false,
      lifecycleState: initialLifecycleState,
      lastInteractionAt: DateTime.now(),
    );
  }

  static final AppSleepService instance = AppSleepService._();

  static const defaultIdleTimeout = Duration(seconds: 20);
  static const defaultInactiveWakelockRetryInterval = Duration(seconds: 10);
  static const _interactionThrottle = Duration(seconds: 1);

  final Duration _idleTimeout;
  final Duration _inactiveWakelockRetryInterval;
  final Future<void> Function(AppSleepReason reason)? _sleepOverride;
  final Future<void> Function(String reason)? _wakeOverride;
  final Future<void> Function(bool value)? _persistSleepingOverride;
  final Future<bool> Function()? _isWakelockHeldOverride;

  Timer? _idleTimer;
  Timer? _scheduledWakeTimer;
  Timer? _inactiveWakelockRetryTimer;
  Future<void> _transition = Future.value();
  DateTime? _lastRecordedInteractionAt;
  bool _initialized = false;
  bool _resumeMetricsOnWake = false;
  bool _resumeNodeOnWake = false;
  bool _resumeIosKeepAliveOnWake = false;
  bool _resumeEpochMonitoringOnWake = false;

  AppSleepSnapshot _snapshot = AppSleepSnapshot(
    isSleeping: false,
    lifecycleState:
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    lastInteractionAt: DateTime.now(),
  );

  AppSleepSnapshot get snapshot => _snapshot;
  bool get isSleeping => _snapshot.isSleeping;
  bool get isAwake => !_snapshot.isSleeping;

  Future<void> initializeForInteractiveApp() async {
    if (_initialized) {
      await _persistSleeping(false);
      _rescheduleIdleTimer();
      return;
    }

    if (_persistSleepingOverride == null) {
      await AppSleepStateStore.load();
    }
    _snapshot = _snapshot.copyWith(
      lifecycleState:
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      lastInteractionAt: DateTime.now(),
      isSleeping: false,
      reason: null,
    );
    _initialized = true;
    await _persistSleeping(false);
    _rescheduleIdleTimer();
    notifyListeners();
  }

  Future<void> handleLifecycleStateChanged(AppLifecycleState state) async {
    _snapshot = _snapshot.copyWith(lifecycleState: state);
    if (state != AppLifecycleState.inactive) {
      _cancelInactiveWakelockRetry();
    }
    _rescheduleIdleTimer();
    notifyListeners();

    switch (state) {
      case AppLifecycleState.resumed:
        await wake(reason: 'lifecycle_resumed');
        break;
      case AppLifecycleState.inactive:
        await sleep(reason: AppSleepReason.lifecycleInactive);
        break;
      case AppLifecycleState.paused:
        await sleep(reason: AppSleepReason.lifecyclePaused);
        break;
      case AppLifecycleState.hidden:
        await sleep(reason: AppSleepReason.lifecycleHidden);
        break;
      case AppLifecycleState.detached:
        await sleep(reason: AppSleepReason.lifecycleDetached);
        break;
    }
  }

  void recordUserInteraction({String source = 'pointer'}) {
    final now = DateTime.now();
    final last = _lastRecordedInteractionAt;
    if (last != null && now.difference(last) < _interactionThrottle) {
      return;
    }

    _lastRecordedInteractionAt = now;
    _snapshot = _snapshot.copyWith(lastInteractionAt: now);
    notifyListeners();

    if (isSleeping) {
      unawaited(wake(reason: 'user_interaction:$source'));
      return;
    }

    _rescheduleIdleTimer();
  }

  Future<void> sleep({required AppSleepReason reason}) {
    _transition = _transition.then((_) => _sleepInternal(reason));
    return _transition;
  }

  Future<void> wake({required String reason}) {
    _transition = _transition.then((_) => _wakeInternal(reason));
    return _transition;
  }

  Future<void> _sleepInternal(AppSleepReason reason) async {
    if (isSleeping) {
      return;
    }

    if (await _shouldBlockSleepForWakelock(reason)) {
      _log.info(
        'Skipping app sleep because wakelock is held',
        context: {'reason': reason.name},
      );
      if (reason == AppSleepReason.lifecycleInactive) {
        _startInactiveWakelockRetry();
      }
      if (_snapshot.lifecycleState == AppLifecycleState.resumed) {
        _rescheduleIdleTimer();
      }
      return;
    }

    _cancelInactiveWakelockRetry();
    _idleTimer?.cancel();
    _idleTimer = null;
    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;

    _resumeMetricsOnWake = MetricsReportingService.instance.isRunning;
    _resumeNodeOnWake = RustBackendService.instance.isRunning;
    _resumeIosKeepAliveOnWake =
        Platform.isIOS && IOSForegroundKeepAliveService.instance.isActive;
    _resumeEpochMonitoringOnWake =
        EpochSlotSchedulerService.instance.isInitialized;
    final nextWakeup = await _resolveNextScheduledWake();

    _snapshot = _snapshot.copyWith(
      isSleeping: true,
      scheduledWakeAt: nextWakeup?.scheduledWakeAt,
      scheduledWakeSlotNumber: nextWakeup?.scheduledWakeSlotNumber,
      reason: reason,
    );
    notifyListeners();
    await _persistSleeping(true);
    _scheduleAutomaticWakeIfNeeded();

    _log.info('Entering app sleep', context: {'reason': reason.name});

    if (_sleepOverride != null) {
      await _sleepOverride(reason);
      return;
    }

    await PlatformAlarmService.instance.initialize();

    if (_resumeMetricsOnWake) {
      await MetricsReportingService.instance.stop();
    }

    AppVersionCheck.instance.stopPeriodicChecks();
    EpochSlotSchedulerService.instance.stopEpochMonitoring();
    await SlotMonitorService.instance.stopMonitoring();

    if (Platform.isAndroid) {
      await AndroidForegroundTaskController.instance
          .stopMonitoring(reason: 'app_sleep:${reason.name}');
    }

    if (_resumeIosKeepAliveOnWake) {
      await IOSForegroundKeepAliveService.instance.stopKeepAlive();
    }

    await PlatformAlarmService.instance.cancelAllAlarms();
    await RustBackendService.instance.pauseNode();
  }

  Future<void> _wakeInternal(String reason) async {
    if (!isSleeping) {
      _rescheduleIdleTimer();
      return;
    }

    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _cancelInactiveWakelockRetry();

    _snapshot = _snapshot.copyWith(
      isSleeping: false,
      scheduledWakeAt: null,
      scheduledWakeSlotNumber: null,
      reason: null,
      lastInteractionAt: DateTime.now(),
    );
    notifyListeners();
    await _persistSleeping(false);

    _log.info('Waking app', context: {'reason': reason});

    if (_wakeOverride != null) {
      await _wakeOverride(reason);
      _rescheduleIdleTimer();
      return;
    }

    if (_resumeNodeOnWake) {
      await RustBackendService.instance.startNode();
      await RustBackendService.instance.resumeNode();
    }

    if (_resumeEpochMonitoringOnWake) {
      await EpochSlotSchedulerService.instance.initialize();
      EpochSlotSchedulerService.instance.startEpochMonitoring();
    }

    if (_resumeMetricsOnWake) {
      await MetricsReportingService.instance.start();
    }

    if (Platform.isAndroid && _resumeNodeOnWake) {
      await AndroidForegroundTaskController.instance
          .startMonitoring(reason: 'app_wake');
    }

    if (Platform.isIOS && _resumeIosKeepAliveOnWake) {
      await IOSForegroundKeepAliveService.instance.startKeepAlive();
    }

    _rescheduleIdleTimer();
  }

  void _rescheduleIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (_snapshot.lifecycleState != AppLifecycleState.resumed || isSleeping) {
      return;
    }

    _idleTimer = Timer(_idleTimeout, () {
      unawaited(sleep(reason: AppSleepReason.idleTimeout));
    });
  }

  Future<bool> _shouldBlockSleepForWakelock(AppSleepReason reason) async {
    if (_isWakelockHeldOverride != null) {
      return _isWakelockHeldOverride();
    }

    try {
      if (Platform.isAndroid) {
        return await AndroidForegroundTaskController.instance.isWakelockHeld();
      }

      if (Platform.isIOS) {
        if (IOSForegroundKeepAliveService.instance.isActive) {
          return true;
        }
        return await WakelockPlus.enabled;
      }
    } catch (e) {
      _log.debug('Failed to query wakelock state: $e');
    }

    return false;
  }

  void _startInactiveWakelockRetry() {
    if (_snapshot.lifecycleState != AppLifecycleState.inactive || isSleeping) {
      return;
    }
    if (_inactiveWakelockRetryTimer != null) {
      return;
    }

    _log.info(
      'Starting inactive wakelock sleep retry loop',
      context: {'interval_seconds': _inactiveWakelockRetryInterval.inSeconds},
    );
    _inactiveWakelockRetryTimer = Timer.periodic(
      _inactiveWakelockRetryInterval,
      (_) => _handleInactiveWakelockRetryTick(),
    );
  }

  void _cancelInactiveWakelockRetry() {
    _inactiveWakelockRetryTimer?.cancel();
    _inactiveWakelockRetryTimer = null;
  }

  void _handleInactiveWakelockRetryTick() {
    if (_snapshot.lifecycleState != AppLifecycleState.inactive || isSleeping) {
      _cancelInactiveWakelockRetry();
      return;
    }

    unawaited(sleep(reason: AppSleepReason.lifecycleInactive));
  }

  Future<({DateTime scheduledWakeAt, int? scheduledWakeSlotNumber})?>
      _resolveNextScheduledWake() async {
    final now = DateTime.now();

    try {
      final epochInfo = await RustBackendService.instance.getEpochInfo();
      final futureWonSlots = epochInfo?.wonSlots
              .where(
                (slot) => DateTime.fromMillisecondsSinceEpoch(
                  slot.expectedTimeMs.toInt(),
                ).isAfter(now),
              )
              .toList() ??
          const [];
      futureWonSlots
          .sort((a, b) => a.expectedTimeMs.compareTo(b.expectedTimeMs));

      if (futureWonSlots.isNotEmpty) {
        final nextSlot = futureWonSlots.first;
        return (
          scheduledWakeAt: DateTime.fromMillisecondsSinceEpoch(
              nextSlot.expectedTimeMs.toInt()),
          scheduledWakeSlotNumber: nextSlot.globalSlot,
        );
      }
    } catch (e) {
      _log.debug('Failed to resolve next wake from epoch info: $e');
    }

    final scheduledSlot = EpochSlotSchedulerService.instance.getNextSlot();
    if (scheduledSlot != null) {
      return (
        scheduledWakeAt: scheduledSlot.slotTime,
        scheduledWakeSlotNumber: scheduledSlot.slotNumber,
      );
    }

    return null;
  }

  void _scheduleAutomaticWakeIfNeeded() {
    final scheduledWakeAt = _snapshot.scheduledWakeAt;
    if (scheduledWakeAt == null) return;

    final delay = scheduledWakeAt.difference(DateTime.now());
    if (delay <= Duration.zero) {
      unawaited(wake(reason: 'scheduled_slot'));
      return;
    }

    _scheduledWakeTimer = Timer(delay, () {
      unawaited(wake(reason: 'scheduled_slot'));
    });
  }

  Future<void> _persistSleeping(bool value) async {
    if (_persistSleepingOverride != null) {
      await _persistSleepingOverride(value);
      return;
    }

    await AppSleepStateStore.setSleeping(value);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _cancelInactiveWakelockRetry();
    super.dispose();
  }
}
