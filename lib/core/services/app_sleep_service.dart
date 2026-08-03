import 'dart:async';
import 'dart:io';

import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/slot_monitor_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
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
        _wakelockMonitorInterval = defaultWakelockMonitorInterval,
        _sleepOverride = null,
        _wakeOverride = null,
        _useStateStore = true,
        _persistSleepingOverride = null,
        _persistEnabledOverride = null,
        _isEnabled = false,
        _isWakelockHeldOverride = null,
        _useWakelockTransitionFlow = Platform.isAndroid;

  @visibleForTesting
  AppSleepService.forTest({
    Duration idleTimeout = defaultIdleTimeout,
    Duration wakelockMonitorInterval = defaultWakelockMonitorInterval,
    Future<void> Function(AppSleepReason reason)? onSleep,
    Future<void> Function(String reason)? onWake,
    Future<void> Function(bool value)? persistSleepState,
    Future<void> Function(bool value)? persistSleepEnabled,
    Future<bool> Function()? isWakelockHeld,
    bool useWakelockTransitionFlow = true,
    AppLifecycleState initialLifecycleState = AppLifecycleState.resumed,
    bool initiallyEnabled = true,
  })  : _idleTimeout = idleTimeout,
        _wakelockMonitorInterval = wakelockMonitorInterval,
        _sleepOverride = onSleep,
        _wakeOverride = onWake,
        _useStateStore = false,
        _persistSleepingOverride = persistSleepState,
        _persistEnabledOverride = persistSleepEnabled,
        _isEnabled = initiallyEnabled,
        _isWakelockHeldOverride = isWakelockHeld,
        _useWakelockTransitionFlow = useWakelockTransitionFlow {
    _snapshot = AppSleepSnapshot(
      isSleeping: false,
      lifecycleState: initialLifecycleState,
      lastInteractionAt: DateTime.now(),
    );
  }

  static final AppSleepService instance = AppSleepService._();

  static const defaultIdleTimeout = Duration(seconds: 300);
  static const defaultWakelockMonitorInterval = Duration(seconds: 1);
  static const _interactionThrottle = Duration(seconds: 1);
  static const manualUiWakeReason = 'manual_ui_wake';

  final Duration _idleTimeout;
  final Duration _wakelockMonitorInterval;
  final Future<void> Function(AppSleepReason reason)? _sleepOverride;
  final Future<void> Function(String reason)? _wakeOverride;
  final bool _useStateStore;
  final Future<void> Function(bool value)? _persistSleepingOverride;
  final Future<void> Function(bool value)? _persistEnabledOverride;
  final Future<bool> Function()? _isWakelockHeldOverride;
  final bool _useWakelockTransitionFlow;

  Timer? _idleTimer;
  Timer? _scheduledWakeTimer;
  Timer? _wakelockMonitorTimer;
  Future<void>? _activeWakelockPoll;
  Future<void> _transition = Future.value();
  DateTime? _lastRecordedInteractionAt;
  bool _initialized = false;
  bool _isEnabled;
  bool _resumeNodeOnWake = false;
  bool _resumeEpochMonitoringOnWake = false;
  bool _awaitingInactivityAfterWakelockRelease = false;
  bool? _lastObservedWakelockHeld;

  AppSleepSnapshot _snapshot = AppSleepSnapshot(
    isSleeping: false,
    lifecycleState:
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    lastInteractionAt: DateTime.now(),
  );

  AppSleepSnapshot get snapshot => _snapshot;
  bool get isEnabled => _isEnabled;
  bool get isSleeping => _snapshot.isSleeping;
  bool get isAwake => !_snapshot.isSleeping;

  Future<void> initializeForInteractiveApp() async {
    if (_useStateStore) {
      await AppSleepStateStore.load();
      _isEnabled = AppSleepStateStore.isEnabled;
    }

    if (_initialized) {
      await _persistSleeping(false);
      await _primeObservedWakelockState();
      _startWakelockMonitor();
      _rescheduleIdleTimer();
      notifyListeners();
      return;
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
    await _primeObservedWakelockState();
    _startWakelockMonitor();
    _rescheduleIdleTimer();
    notifyListeners();
  }

  /// Stops and drains process-level sleep work before replacing the
  /// interactive runtime.
  ///
  /// This service is a process singleton rather than container-owned, so
  /// disposing the old [ProviderContainer] is not sufficient by itself.
  Future<void> stopForRuntimeRestart() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _wakelockMonitorTimer?.cancel();
    _wakelockMonitorTimer = null;

    await _activeWakelockPoll;
    await _transition;

    _transition = Future.value();
    _initialized = false;
    _lastRecordedInteractionAt = null;
    _resumeNodeOnWake = false;
    _resumeEpochMonitoringOnWake = false;
    _awaitingInactivityAfterWakelockRelease = false;
    _lastObservedWakelockHeld = null;
    _snapshot = AppSleepSnapshot(
      isSleeping: false,
      lifecycleState:
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
      lastInteractionAt: DateTime.now(),
    );
    await _persistSleeping(false);
  }

  Future<void> handleLifecycleStateChanged(AppLifecycleState state) async {
    _snapshot = _snapshot.copyWith(lifecycleState: state);
    _rescheduleIdleTimer();
    notifyListeners();

    if (!_isEnabled) {
      if (isSleeping) {
        await _wakeInternal('automatic_sleep_disabled');
      }
      return;
    }

    if (_useWakelockTransitionFlow) {
      await _handleLifecycleInactivityChange(state);
      return;
    }

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
    if (!_isEnabled && !isSleeping) {
      return;
    }

    if (isSleeping) {
      // Sleep only pauses the node — the UI stays interactive (there is no
      // full-screen sleep overlay), so any touch while foregrounded is the
      // wake gesture. Bypasses the interaction throttle so the wake isn't
      // delayed by an interaction recorded just before sleep began.
      if (_snapshot.lifecycleState == AppLifecycleState.resumed) {
        final now = DateTime.now();
        _lastRecordedInteractionAt = now;
        _snapshot = _snapshot.copyWith(lastInteractionAt: now);
        notifyListeners();
        unawaited(wake(reason: manualUiWakeReason));
      }
      return;
    }

    final now = DateTime.now();
    final last = _lastRecordedInteractionAt;
    if (last != null && now.difference(last) < _interactionThrottle) {
      return;
    }

    _lastRecordedInteractionAt = now;
    _snapshot = _snapshot.copyWith(lastInteractionAt: now);
    notifyListeners();

    _rescheduleIdleTimer();
  }

  Future<void> setEnabled(bool value) {
    _transition = _transition.then((_) => _setEnabledInternal(value));
    return _transition;
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
    if (!_isEnabled) {
      return;
    }

    if (isSleeping) {
      return;
    }

    if (!_useWakelockTransitionFlow && await _queryWakelockHeld()) {
      _log.info(
        'Skipping app sleep because wakelock is held',
        context: {'reason': reason.name},
      );
      if (_snapshot.lifecycleState == AppLifecycleState.resumed) {
        _rescheduleIdleTimer();
      }
      return;
    }

    _idleTimer?.cancel();
    _idleTimer = null;
    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _awaitingInactivityAfterWakelockRelease = false;

    _resumeNodeOnWake = RustBackendService.instance.isRunning;
    _resumeEpochMonitoringOnWake =
        EpochSlotSchedulerService.instance.isInitialized;

    _snapshot = _snapshot.copyWith(
      isSleeping: true,
      scheduledWakeAt: null,
      scheduledWakeSlotNumber: null,
      reason: reason,
    );
    notifyListeners();
    await _persistSleeping(true);

    if (!_useWakelockTransitionFlow) {
      final nextWakeup = await _resolveNextScheduledWake();
      _snapshot = _snapshot.copyWith(
        scheduledWakeAt: nextWakeup?.scheduledWakeAt,
        scheduledWakeSlotNumber: nextWakeup?.scheduledWakeSlotNumber,
      );
      notifyListeners();
      _scheduleAutomaticWakeIfNeeded();
    }

    _log.info('Entering app sleep', context: {'reason': reason.name});

    if (_sleepOverride != null) {
      await _sleepOverride(reason);
      return;
    }

    await PlatformAlarmService.instance.initialize();

    AppVersionCheck.instance.stopPeriodicChecks();
    EpochSlotSchedulerService.instance.stopEpochMonitoring();
    await SlotMonitorService.instance.stopMonitoring();

    if (Platform.isAndroid && !_useWakelockTransitionFlow) {
      await AndroidForegroundTaskController.instance
          .stopMonitoring(reason: 'app_sleep:${reason.name}');
    }

    if (Platform.isAndroid && !_useWakelockTransitionFlow) {
      await PlatformAlarmService.instance.cancelAllAlarms();
    }
    await RustBackendService.instance.pauseNode();
  }

  Future<void> _wakeInternal(String reason) async {
    if (!isSleeping) {
      _rescheduleIdleTimer();
      return;
    }

    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _awaitingInactivityAfterWakelockRelease = false;

    _snapshot = _snapshot.copyWith(
      isSleeping: false,
      scheduledWakeAt: null,
      scheduledWakeSlotNumber: null,
      reason: null,
      lastInteractionAt: DateTime.now(),
    );
    await _persistSleeping(false);

    _log.info('Waking app', context: {'reason': reason});

    if (_wakeOverride != null) {
      await _wakeOverride(reason);
      notifyListeners();
      _rescheduleIdleTimer();
      return;
    }

    if (_shouldResumeNodeDirectlyOnWake(reason)) {
      await RustBackendService.instance.startNode();
      await RustBackendService.instance.resumeNode();
    }

    if (_resumeEpochMonitoringOnWake) {
      await EpochSlotSchedulerService.instance.initialize();
      EpochSlotSchedulerService.instance.startEpochMonitoring();
    }

    if (!_useWakelockTransitionFlow &&
        Platform.isAndroid &&
        _resumeNodeOnWake) {
      await AndroidForegroundTaskController.instance
          .startMonitoring(reason: 'app_wake');
    }

    notifyListeners();
    _rescheduleIdleTimer();
  }

  Future<void> _setEnabledInternal(bool value) async {
    if (_isEnabled == value) {
      return;
    }

    _isEnabled = value;
    await _persistEnabled(value);

    if (!value) {
      _idleTimer?.cancel();
      _idleTimer = null;
      _scheduledWakeTimer?.cancel();
      _scheduledWakeTimer = null;
      _awaitingInactivityAfterWakelockRelease = false;

      if (isSleeping) {
        await _wakeInternal('automatic_sleep_disabled');
        return;
      }

      notifyListeners();
      return;
    }

    _snapshot = _snapshot.copyWith(lastInteractionAt: DateTime.now());
    _rescheduleIdleTimer();
    notifyListeners();
  }

  void _rescheduleIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;

    if (!_isEnabled ||
        _snapshot.lifecycleState != AppLifecycleState.resumed ||
        isSleeping ||
        (_useWakelockTransitionFlow &&
            !_awaitingInactivityAfterWakelockRelease)) {
      return;
    }

    _idleTimer = Timer(_idleTimeout, () {
      unawaited(sleep(reason: AppSleepReason.idleTimeout));
    });
  }

  Future<bool> _queryWakelockHeld() async {
    if (_isWakelockHeldOverride != null) {
      return _isWakelockHeldOverride();
    }

    try {
      if (Platform.isAndroid) {
        return await AndroidForegroundTaskController.instance.isWakelockHeld();
      }

      if (Platform.isIOS) {
        return await WakelockPlus.enabled;
      }
    } catch (e) {
      _log.debug('Failed to query wakelock state: $e');
    }

    return false;
  }

  Future<void> _primeObservedWakelockState() async {
    if (!_useWakelockTransitionFlow) {
      return;
    }

    _lastObservedWakelockHeld = await _queryWakelockHeld();
  }

  void _startWakelockMonitor() {
    if (!_useWakelockTransitionFlow) {
      return;
    }

    _wakelockMonitorTimer?.cancel();
    _wakelockMonitorTimer = Timer.periodic(
      _wakelockMonitorInterval,
      (_) => _startWakelockPoll(),
    );
  }

  void _startWakelockPoll() {
    if (_activeWakelockPoll != null) {
      return;
    }

    final poll = _pollObservedWakelockState();
    _activeWakelockPoll = poll;
    unawaited(poll.whenComplete(() {
      if (identical(_activeWakelockPoll, poll)) {
        _activeWakelockPoll = null;
      }
    }));
  }

  Future<void> _pollObservedWakelockState() async {
    try {
      final isHeld = await _queryWakelockHeld();
      _handleObservedWakelockState(isHeld, source: 'poll');
    } catch (error) {
      _log.debug('Failed to poll wakelock state: $error');
    }
  }

  void handleNativeEvent(String eventType, Map<String, dynamic> eventData) {
    if (!_useWakelockTransitionFlow) {
      return;
    }

    switch (eventType) {
      case 'android_native_wakelock_acquired':
        _handleObservedWakelockState(true, source: eventType);
        break;
      case 'android_native_wakelock_released':
        _handleObservedWakelockState(false, source: eventType);
        break;
    }
  }

  void _handleObservedWakelockState(bool isHeld, {required String source}) {
    final previous = _lastObservedWakelockHeld;
    _lastObservedWakelockHeld = isHeld;

    if (previous == null || previous == isHeld) {
      return;
    }

    if (previous && !isHeld) {
      _handleWakelockReleased(source);
      return;
    }

    if (!previous && isHeld) {
      _handleWakelockAcquired(source);
    }
  }

  void _handleWakelockReleased(String source) {
    if (isSleeping) {
      return;
    }

    if (!_isEnabled) {
      _awaitingInactivityAfterWakelockRelease = false;
      _rescheduleIdleTimer();
      return;
    }

    _awaitingInactivityAfterWakelockRelease = true;
    _log.info(
      'Observed wakelock release; awaiting inactivity confirmation',
      context: {
        'source': source,
        'lifecycle_state': _snapshot.lifecycleState.name,
      },
    );

    _rescheduleIdleTimer();

    final sleepReason = _sleepReasonForLifecycleState(_snapshot.lifecycleState);
    if (sleepReason != null) {
      unawaited(sleep(reason: sleepReason));
    }
  }

  void _handleWakelockAcquired(String source) {
    _awaitingInactivityAfterWakelockRelease = false;
    _rescheduleIdleTimer();

    _log.info(
      'Observed wakelock acquire',
      context: {
        'source': source,
        'is_sleeping': isSleeping,
      },
    );

    if (!isSleeping) {
      return;
    }

    unawaited(_persistSleeping(false));
    unawaited(wake(reason: 'wakelock_acquired:$source'));
  }

  bool _shouldResumeNodeDirectlyOnWake(String reason) {
    if (!_resumeNodeOnWake) {
      return false;
    }

    if (!_useWakelockTransitionFlow) {
      return true;
    }

    return reason == manualUiWakeReason &&
        _snapshot.lifecycleState == AppLifecycleState.resumed;
  }

  Future<void> _handleLifecycleInactivityChange(AppLifecycleState state) async {
    if (!_awaitingInactivityAfterWakelockRelease || isSleeping) {
      return;
    }

    final sleepReason = _sleepReasonForLifecycleState(state);
    if (sleepReason != null) {
      await sleep(reason: sleepReason);
    }
  }

  AppSleepReason? _sleepReasonForLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return null;
      case AppLifecycleState.inactive:
        return AppSleepReason.lifecycleInactive;
      case AppLifecycleState.paused:
        return AppSleepReason.lifecyclePaused;
      case AppLifecycleState.hidden:
        return AppSleepReason.lifecycleHidden;
      case AppLifecycleState.detached:
        return AppSleepReason.lifecycleDetached;
    }
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

  Future<void> _persistEnabled(bool value) async {
    if (_persistEnabledOverride != null) {
      await _persistEnabledOverride(value);
      return;
    }

    await AppSleepStateStore.setEnabled(value);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _scheduledWakeTimer?.cancel();
    _scheduledWakeTimer = null;
    _wakelockMonitorTimer?.cancel();
    _wakelockMonitorTimer = null;
    super.dispose();
  }
}
