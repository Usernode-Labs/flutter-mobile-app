import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

/// Owns "start the node" and "stop the node" as atomic operations that keep
/// the Android block-production support (alarm watchdog, foreground service,
/// audit) in sync with the node runtime.
///
/// Before this existed, every start/stop call site hand-rolled the same
/// Android wiring (bridge v4 handlers, standalone dapp entry, the
/// account-removed listener), and each copy could drift — a start that
/// forgets to re-arm the watchdog silently kills background block
/// production until the next interactive launch.
///
/// Deliberately NOT routed through here:
/// - `AppSleepService` wake/sleep — the sleep service owns a richer
///   monitoring state machine (wakelock transition flow, epoch monitoring)
///   and starting monitoring is decoupled from starting the node there.
/// - The audit service's own headless ensure-running path — that IS the
///   watchdog machinery; wrapping it back through the coordinator would
///   recurse the audit.
/// - Identity suspension stops (session controller / provisioning) — those
///   intentionally stop only the runtime; the account-removed listener does
///   the full teardown when ownership is actually gone.
class NodeLifecycleCoordinator {
  NodeLifecycleCoordinator({
    Future<bool> Function()? startBackend,
    Future<void> Function()? stopBackend,
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
  final void Function() _enableWatchdogRecovery;
  final void Function() _disableWatchdogRecovery;
  final void Function({required String reason}) _auditBestEffort;
  final Future<void> Function() _onNodeStarted;
  final Future<void> Function({required String reason}) _stopMonitoring;
  final Future<void> Function() _cancelAllAlarms;
  final Future<void> Function() _cancelAlarmWatchdog;
  final bool Function() _isAndroid;

  /// Starts the node and, on Android, wires block-production support to the
  /// outcome: a successful start re-arms watchdog recovery, runs an audit
  /// (so the fg_resume alarm and WorkManager watchdog get scheduled for the
  /// new runtime), and brings up the foreground service; a failed start
  /// disables recovery and cancels the watchdog so it can't keep waking a
  /// node that won't come up.
  ///
  /// Returns whether the node is running afterwards. `reason` tags the
  /// audit/monitoring logs with the initiating surface.
  Future<bool> startNode({required String reason}) async {
    final started = await _startBackend();
    if (!_isAndroid()) return started;
    if (started) {
      // Enable BEFORE onNodeStarted so the controller's own re-arm check
      // sees recovery already on and doesn't queue a duplicate audit.
      _enableWatchdogRecovery();
      _auditBestEffort(reason: reason);
      await _onNodeStarted();
    } else {
      _disableWatchdogRecovery();
      await _cancelAlarmWatchdog();
    }
    return started;
  }

  /// Stops the node and, on Android, tears down block-production support:
  /// recovery is disabled first so no audit re-arms alarms mid-teardown,
  /// then monitoring/foreground service stops, then the runtime, then any
  /// already-scheduled alarms and the watchdog are cancelled. Idempotent —
  /// stopping an already-stopped node is a no-op all the way down.
  Future<void> stopNode({required String reason}) async {
    if (_isAndroid()) {
      _disableWatchdogRecovery();
      await _stopMonitoring(reason: reason);
    }
    await _stopBackend();
    if (_isAndroid()) {
      await _cancelAllAlarms();
      await _cancelAlarmWatchdog();
    }
  }
}
