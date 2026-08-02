import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

/// What the platform (SV chrome) has most recently asked of the node runtime
/// in this process. Not persisted: a fresh process starts at [unset], which
/// means "no explicit request yet" — with an account present, recovery stays
/// armed so headless recovery paths can restart production after reboots and
/// process death (matching pre-thin-shell semantics).
enum PlatformNodeIntent { unset, start, stop }

/// Owns the node runtime and the Android block-production support (alarm
/// watchdog, foreground service, audit) as a *desired-state reconciler*.
///
/// Entry points report facts (account presence, platform start/stop
/// requests); [_reconcile] derives what should be true and does ALL the
/// wiring in one idempotent place. Before this existed, every entry point
/// (bootstrap, bridge handlers, standalone dapp entry, the account-removed
/// listener) hand-rolled the same wiring with its own partial view of the
/// world, and each copy could drift — three separate review findings on the
/// thin-shell migration were entry points either forgetting a step or
/// flipping the watchdog flag on a stale assumption.
///
/// The two derived predicates are deliberately distinct:
/// - [recoveryDesired] — the watchdog machinery should stay armed so
///   headless recovery events (boot receiver, WorkManager watchdog,
///   force-stop recovery) can pass the audit gate and start the node
///   themselves.
/// - [runDesired] — the node should be actively brought up *now*. Requires
///   an explicit platform start: on interactive cold boots the start is
///   deferred to the platform bridge, so an account alone arms recovery
///   without starting anything.
///
/// Deliberately NOT routed through here:
/// - `AppSleepService` wake/sleep — the sleep service owns a richer
///   monitoring state machine (wakelock transition flow, epoch monitoring)
///   and starting monitoring is decoupled from starting the node there.
///   Reconcile only *reads* the sleep flag so it never starts the node into
///   an active sleep.
/// - The audit service's own headless ensure-running path — that IS the
///   watchdog machinery; wrapping it back through the coordinator would
///   recurse the audit.
/// - `AndroidForegroundTaskController.startMonitoring`'s re-arm of watchdog
///   recovery — that is the native headless start path (alarm wakes where
///   no bridge exists) and must stay self-contained.
class NodeLifecycleCoordinator {
  NodeLifecycleCoordinator({
    Future<bool> Function()? startBackend,
    Future<void> Function()? stopBackend,
    bool Function()? isNodeRunning,
    bool Function()? isSleeping,
    void Function()? enableWatchdogRecovery,
    void Function()? disableWatchdogRecovery,
    void Function({required String reason})? auditBestEffort,
    Future<void> Function()? onNodeStarted,
    Future<void> Function({required String reason})? stopMonitoring,
    Future<void> Function()? cancelAllAlarms,
    Future<void> Function()? cancelAlarmWatchdog,
    bool Function()? isAndroid,
  })  : _startBackend =
            startBackend ?? (() => RustBackendService.instance.startNode()),
        _stopBackend =
            stopBackend ?? (() => RustBackendService.instance.stopNode()),
        _isNodeRunning =
            isNodeRunning ?? (() => RustBackendService.instance.isRunning),
        _isSleeping = isSleeping ?? (() => AppSleepStateStore.isSleeping),
        _enableWatchdogRecovery = enableWatchdogRecovery ??
            (() => BlockProductionAlarmAuditService.instance
                .enableWatchdogRecovery()),
        _disableWatchdogRecovery = disableWatchdogRecovery ??
            (() => BlockProductionAlarmAuditService.instance
                .disableWatchdogRecovery()),
        _auditBestEffort = auditBestEffort ??
            (({required String reason}) => BlockProductionAlarmAuditService
                .instance
                .auditBestEffort(reason: reason)),
        _onNodeStarted = onNodeStarted ??
            (() => AndroidForegroundTaskController.instance.onNodeStarted()),
        _stopMonitoring = stopMonitoring ??
            (({required String reason}) => AndroidForegroundTaskController
                .instance
                .stopMonitoring(reason: reason)),
        _cancelAllAlarms = cancelAllAlarms ??
            (() => PlatformAlarmService.instance.cancelAllAlarms()),
        _cancelAlarmWatchdog = cancelAlarmWatchdog ??
            (() => PlatformAlarmService.instance.cancelAlarmWatchdog()),
        _isAndroid = isAndroid ??
            (() => defaultTargetPlatform == TargetPlatform.android);

  static NodeLifecycleCoordinator instance = NodeLifecycleCoordinator();

  final Future<bool> Function() _startBackend;
  final Future<void> Function() _stopBackend;
  final bool Function() _isNodeRunning;
  final bool Function() _isSleeping;
  final void Function() _enableWatchdogRecovery;
  final void Function() _disableWatchdogRecovery;
  final void Function({required String reason}) _auditBestEffort;
  final Future<void> Function() _onNodeStarted;
  final Future<void> Function({required String reason}) _stopMonitoring;
  final Future<void> Function() _cancelAllAlarms;
  final Future<void> Function() _cancelAlarmWatchdog;
  final bool Function() _isAndroid;

  // ── Facts ────────────────────────────────────────────────────────────
  bool _hasAccount = false;
  PlatformNodeIntent _intent = PlatformNodeIntent.unset;

  // Serializes reconciles so overlapping requests (e.g. a bridge stop racing
  // an account-removed event) can't interleave their start/stop sequences.
  Future<void> _serial = Future<void>.value();

  @visibleForTesting
  PlatformNodeIntent get intent => _intent;

  @visibleForTesting
  bool get hasAccount => _hasAccount;

  // ── Pure derivation (table-tested) ───────────────────────────────────

  /// The node should be actively brought up right now.
  static bool runDesired({
    required bool hasAccount,
    required PlatformNodeIntent intent,
    required bool sleeping,
  }) =>
      hasAccount && intent == PlatformNodeIntent.start && !sleeping;

  /// The Android watchdog machinery should stay armed so headless recovery
  /// events can start the node through the audit.
  static bool recoveryDesired({
    required bool hasAccount,
    required PlatformNodeIntent intent,
  }) =>
      hasAccount && intent != PlatformNodeIntent.stop;

  // ── Entry points: report facts, then reconcile ───────────────────────

  /// Platform (or a standalone dapp entry) explicitly requests a node start.
  /// Callers gate on a settled identity, so an explicit start also implies
  /// an account-backed session. Returns whether the node is running after
  /// reconciliation.
  Future<bool> startNode({required String reason}) => _serialized(() {
        _hasAccount = true;
        _intent = PlatformNodeIntent.start;
        return _reconcile(reason: reason);
      });

  /// Platform explicitly requests a node stop. Tears down the runtime and
  /// all Android production support so nothing wakes a node that was
  /// deliberately stopped.
  Future<void> stopNode({required String reason}) => _serialized(() async {
        _intent = PlatformNodeIntent.stop;
        await _reconcile(reason: reason);
      });

  /// Cold-start facts from bootstrap. With an account and no explicit
  /// platform request yet, this arms recovery without starting the node —
  /// interactive boots defer the start to the platform bridge, while
  /// headless recovery events can still start it through the audit gate.
  Future<bool> reportColdBoot({
    required bool hasAccount,
    String reason = 'cold_boot',
  }) =>
      _serialized(() {
        _hasAccount = hasAccount;
        return _reconcile(reason: reason);
      });

  /// Account presence changed at runtime (login created the first account,
  /// or the last account was removed). Removal resets any platform intent:
  /// a later login must ask for a start explicitly.
  Future<void> reportAccountsChanged({
    required bool hasAccount,
    String reason = 'accounts_changed',
  }) =>
      _serialized(() async {
        _hasAccount = hasAccount;
        if (!hasAccount) _intent = PlatformNodeIntent.unset;
        await _reconcile(reason: reason);
      });

  // ── Reconcile ─────────────────────────────────────────────────────────

  Future<bool> _reconcile({required String reason}) async {
    final wantRecovery =
        recoveryDesired(hasAccount: _hasAccount, intent: _intent);
    final wantRun = runDesired(
      hasAccount: _hasAccount,
      intent: _intent,
      sleeping: _isSleeping(),
    );

    if (!wantRecovery) {
      // Deliberate stop or no account: full teardown. Recovery is disabled
      // first so no audit re-arms alarms mid-teardown; alarms are cancelled
      // after the runtime is down. Every step is idempotent.
      if (_isAndroid()) {
        _disableWatchdogRecovery();
        await _stopMonitoring(reason: reason);
      }
      await _stopBackend();
      if (_isAndroid()) {
        await _cancelAllAlarms();
        await _cancelAlarmWatchdog();
      }
      return false;
    }

    var running = _isNodeRunning();
    if (wantRun) {
      // Backend start is idempotent; calling it while running is a no-op
      // that reports the (running) outcome.
      running = await _startBackend();
    }

    if (!_isAndroid()) return running;

    if (running) {
      // Enable BEFORE onNodeStarted so the controller's own re-arm check
      // sees recovery already on and doesn't queue a duplicate audit.
      _enableWatchdogRecovery();
      _auditBestEffort(reason: reason);
      await _onNodeStarted();
    } else if (wantRun) {
      // Explicit start failed: disarm so the watchdog can't keep waking a
      // node that won't come up. The next successful start re-arms.
      _disableWatchdogRecovery();
      await _cancelAlarmWatchdog();
    } else {
      // Account present, start deferred (or blocked by sleep): keep
      // recovery armed so headless recovery events can pass the audit gate
      // and start the node themselves. No audit here — interactive boots
      // wait for the platform.
      _enableWatchdogRecovery();
    }
    return running;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _serial.then((_) => action());
    _serial = result.then((_) {}, onError: (_) {});
    return result;
  }
}
