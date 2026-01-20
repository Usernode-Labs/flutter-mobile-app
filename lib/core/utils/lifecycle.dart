import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import '../../features/node/node_service.dart';
import '../../features/metrics/metrics_collector_service.dart';
import '../services/android_foreground_task_controller.dart';
import '../services/platform_alarm_service.dart';

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

      // 1. Check and restart node if needed (Android only)
      if (Platform.isAndroid) {
        await _ensureNodeRunning();
      }

      // 2. Check for epoch transition and reschedule if needed
      await _checkEpochTransition();

      // 3. Verify scheduled alarms still exist
      await _verifyScheduledAlarms();

      _log.info('App resume handling complete');
    } catch (e) {
      _log.error('Error handling app resume: $e');
    } finally {
      _isHandlingResume = false;
    }
  }

  /// Handle app paused
  Future<void> _handleAppPaused() async {
    _log.debug('App paused');
    if (!Platform.isAndroid) return;

    if (await PlatformAlarmService.instance.isForegroundServiceRunning()) {
      _log.info('Foreground service running; not pausing Rust node');
    } else {
      _log.info('Foreground service not running; pausing Rust node');
      await RustBackendService.instance.pauseNode();
      if (await PlatformAlarmService.instance.isForegroundServiceRunning()) {
        _log.info('Foreground service started; ensuring Rust node is resumed');
        await RustBackendService.instance.resumeNode();
      }
    }
  }

  /// Ensure node is running (Android only)
  Future<void> _ensureNodeRunning() async {
    try {
      final rustBackend = RustBackendService.instance;

      if (!rustBackend.isRunning) {
        _log.warn('Node not running on resume, restarting...');

        await rustBackend.startNode();
        await rustBackend.resumeNode();

        if (rustBackend.isRunning) {
          _log.info('✓ Node successfully restarted');
        } else {
          _log.error('✗ Failed to restart node');
        }
      } else {
        _log.debug('Node already running');
      }
    } catch (e) {
      _log.error('Error ensuring node running: $e');
    }
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
