import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import '../../features/metrics/metrics_collector_service.dart';
import '../services/android_foreground_task_controller.dart';

final _log = LoggingService.instance.withTag('usernode/Lifecycle');

/// Enhanced app lifecycle observer with background block production support
///
/// Handles:
/// - Epoch transition detection and slot rescheduling
/// - Alarm verification after app resume
/// - Node restart on Android if not running
class AppLifecycleLogger with WidgetsBindingObserver {
  static AppLifecycleLogger? _instance;

  // Track if we're currently handling resume to avoid concurrent processing
  bool _isHandlingResume = false;

  static void register() {
    _instance ??= AppLifecycleLogger();
    WidgetsBinding.instance.addObserver(_instance!);
    _log.debug('Lifecycle observer registered');
  }

  static void unregister() {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      _log.debug('Lifecycle observer removed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    _log.info('App lifecycle state changed: ${state.name}');

    // Update metrics collector with new state
    MetricsCollectorService.instance.updateAppLifecycleState(state);

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
      await _checkEpochTransition();
      _log.info('App resume handling complete');
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

  /// Check if epoch has changed and reschedule slots if needed
  ///
  Future<void> _checkEpochTransition() async {
    try {
      if (!Platform.isAndroid) return;

      _log.info('Resuming Android foreground VRF monitoring');
      await AndroidForegroundTaskController.instance
          .startMonitoring(reason: 'app_resumed');
    } catch (e) {
      _log.error('Error checking epoch transition: $e');
    }
  }

}
