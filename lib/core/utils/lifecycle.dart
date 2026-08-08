import 'dart:async';

import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:flutter/widgets.dart';

import '../../features/metrics/metrics_collector_service.dart';

final _log = LoggingService.instance.withTag('usernode/Lifecycle');

/// Enhanced app lifecycle observer with background block production support
///
/// Handles:
/// - Epoch transition detection and slot rescheduling
/// - Alarm verification after app resume
/// - Node restart on Android if not running
class AppLifecycleLogger with WidgetsBindingObserver {
  static AppLifecycleLogger? _instance;
  static VoidCallback? onForegroundResume;

  // Track if we're currently handling resume to avoid concurrent processing
  bool _isHandlingResume = false;

  static void register() {
    if (_instance != null) return;

    final instance = AppLifecycleLogger();
    _instance = instance;
    WidgetsBinding.instance.addObserver(instance);
    _log.debug('Lifecycle observer registered');
  }

  static void unregister() {
    final instance = _instance;
    if (instance == null) return;

    WidgetsBinding.instance.removeObserver(instance);
    _instance = null;
    _log.debug('Lifecycle observer removed');
  }

  static void closeForTerminalReset() {
    onForegroundResume = null;
    unregister();
  }

  @visibleForTesting
  static bool get isRegistered => _instance != null;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _log.info('App lifecycle state changed: ${state.name}');

    // Update metrics collector with new state
    MetricsCollectorService.instance.updateAppLifecycleState(state);
    await AppSleepService.instance.handleLifecycleStateChanged(state);
    unawaited(
      ObservabilityReportingService.instance.reportLifecycleStateChanged(state),
    );

    switch (state) {
      case AppLifecycleState.resumed:
        await _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        await _handleAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // No special handling needed
        break;
    }
  }

  /// Handle app resumed - check for epoch changes and verify alarms
  Future<void> _handleAppResumed() async {
    if (_isHandlingResume) {
      _log.debug('Already handling resume, skipping');
      return;
    }

    _isHandlingResume = true;

    try {
      _log.info('Handling app resume...');

      // Native wake/resume is handled by AppSleepService. Resume work here
      // should be limited to foreground-only recovery tasks.
      await _verifyScheduledAlarms();

      _log.info('App resume handling complete');
      onForegroundResume?.call();
    } catch (e) {
      _log.error('Error handling app resume: $e');
    } finally {
      _isHandlingResume = false;
    }
  }

  /// Handle app paused
  Future<void> _handleAppPaused() async {
    // Rust Node will be paused by the foreground service or MainActivity destructor.
  }

  /// Verify that scheduled alarms still exist (could be cleared by system)
  ///
  Future<void> _verifyScheduledAlarms() async {
    try {
      _log.debug(
          'Alarm verification no-op (handled by AlarmManager scheduling)');
    } catch (e) {
      _log.error('Error verifying scheduled alarms: $e');
    }
  }
}
