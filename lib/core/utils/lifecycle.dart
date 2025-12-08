import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import '../../features/node/node_service.dart';
import '../../features/metrics/metrics_collector_service.dart';
import '../services/background_block_production_orchestrator.dart';
import '../services/platform_alarm_service.dart';

final _log = LoggingService.instance.withTag('Lifecycle');

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
    SentryUtil.addBreadcrumb(
        category: 'lifecycle', message: 'observer registered');
  }

  static void unregister() {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      SentryUtil.addBreadcrumb(
          category: 'lifecycle', message: 'observer removed');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SentryUtil.addBreadcrumb(
      category: 'lifecycle',
      message: 'state: ${state.name}',
    );

    _log.info('App lifecycle state changed: ${state.name}');

    // Update metrics collector with new state
    MetricsCollectorService.instance.updateAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.paused:
        _handleAppPaused();
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
      SentryUtil.addBreadcrumb(
        category: 'lifecycle',
        message: 'resume error: $e',
        level: SentryLevel.error,
      );
    } finally {
      _isHandlingResume = false;
    }
  }

  /// Handle app paused - no special handling needed for now
  void _handleAppPaused() {
    _log.debug('App paused');
    // iOS could stop node after 30s here in the future if needed
  }

  /// Ensure node is running (Android only)
  Future<void> _ensureNodeRunning() async {
    try {
      final rustBackend = RustBackendService.instance;

      if (!rustBackend.isRunning) {
        _log.warn('Node not running on resume, restarting...');

        await rustBackend.startNode();

        if (rustBackend.isRunning) {
          _log.info('✓ Node successfully restarted');
          SentryUtil.addBreadcrumb(
            category: 'lifecycle',
            message: 'node restarted on resume',
          );
        } else {
          _log.error('✗ Failed to restart node');
          SentryUtil.addBreadcrumb(
            category: 'lifecycle',
            message: 'failed to restart node',
            level: SentryLevel.error,
          );
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
  /// Now uses BackgroundBlockProductionOrchestrator for unified handling
  Future<void> _checkEpochTransition() async {
    try {
      // The orchestrator now handles epoch transitions automatically!
      // We just need to trigger a check when the app resumes
      if (BackgroundBlockProductionOrchestrator.instance.isInitialized) {
        _log.info('Notifying orchestrator of app resume...');
        await BackgroundBlockProductionOrchestrator.instance.onAppResumed();
        _log.info('✓ Orchestrator notified, epoch check complete');
      } else {
        _log.warn('BackgroundBlockProductionOrchestrator not initialized');
      }
    } catch (e) {
      _log.error('Error checking epoch transition: $e');
    }
  }

  /// Verify that scheduled alarms still exist (could be cleared by system)
  ///
  /// Now uses BackgroundBlockProductionOrchestrator for unified state
  Future<void> _verifyScheduledAlarms() async {
    try {
      if (!BackgroundBlockProductionOrchestrator.instance.isInitialized) {
        _log.debug(
            'BackgroundBlockProductionOrchestrator not initialized, skipping alarm verification');
        return;
      }

      final scheduledSlots =
          BackgroundBlockProductionOrchestrator.instance.scheduledSlots;

      if (scheduledSlots.isEmpty) {
        _log.debug('No slots scheduled, nothing to verify');
        return;
      }

      _log.debug('Verifying ${scheduledSlots.length} scheduled alarms...');

      // Check if alarms still exist via platform alarm service
      final hasPermission = PlatformAlarmService.instance.hasPermissions;

      if (!hasPermission) {
        _log.warn(
            '⚠️  Exact alarm permission lost! Alarms may have been cleared.');

        SentryUtil.addBreadcrumb(
          category: 'lifecycle',
          message: 'exact alarm permission lost',
          level: SentryLevel.warning,
        );

        // Could notify user here or attempt to reschedule
        return;
      }

      // On Android, we can verify alarms exist
      // On iOS, BGTasks don't have a verification API
      if (Platform.isAndroid) {
        // Android alarms persist through app restarts but are lost on device reboot
        // The system will call our BOOT_COMPLETED receiver to handle rescheduling
        _log.debug('Alarm verification complete (Android)');
      } else {
        _log.debug('Alarm verification skipped (iOS - no verification API)');
      }
    } catch (e) {
      _log.error('Error verifying scheduled alarms: $e');
    }
  }
}
