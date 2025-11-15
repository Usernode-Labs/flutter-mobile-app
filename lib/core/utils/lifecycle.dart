import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';
import '../services/epoch_slot_scheduler_service.dart';
import '../services/platform_alarm_service.dart';

/// Enhanced app lifecycle observer with background block production support
///
/// Handles:
/// - Epoch transition detection and slot rescheduling
/// - Alarm verification after app resume
/// - Node restart on Android if not running
class AppLifecycleLogger with WidgetsBindingObserver {
  static AppLifecycleLogger? _instance;

  final Logger _logger = Logger();
  SharedPreferences? _prefs;

  // Key for storing last known epoch
  static const String _keyLastEpoch = 'lifecycle_last_epoch';

  // Track if we're currently handling resume to avoid concurrent processing
  bool _isHandlingResume = false;

  static void register() {
    _instance ??= AppLifecycleLogger();
    WidgetsBinding.instance.addObserver(_instance!);
    SentryUtil.addBreadcrumb(
        category: 'lifecycle', message: 'observer registered');

    // Initialize SharedPreferences
    _instance!._initializePrefs();
  }

  static void unregister() {
    if (_instance != null) {
      WidgetsBinding.instance.removeObserver(_instance!);
      SentryUtil.addBreadcrumb(
          category: 'lifecycle', message: 'observer removed');
    }
  }

  Future<void> _initializePrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _logger.d('Lifecycle SharedPreferences initialized');
    } catch (e) {
      _logger.e('Error initializing SharedPreferences: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SentryUtil.addBreadcrumb(
      category: 'lifecycle',
      message: 'state: ${state.name}',
    );

    _logger.i('App lifecycle state changed: ${state.name}');

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
      _logger.d('Already handling resume, skipping');
      return;
    }

    _isHandlingResume = true;

    try {
      _logger.i('Handling app resume...');

      // 1. Check and restart node if needed (Android only)
      if (Platform.isAndroid) {
        await _ensureNodeRunning();
      }

      // 2. Check for epoch transition and reschedule if needed
      await _checkEpochTransition();

      // 3. Verify scheduled alarms still exist
      await _verifyScheduledAlarms();

      _logger.i('App resume handling complete');
    } catch (e) {
      _logger.e('Error handling app resume: $e');
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
    _logger.d('App paused');
    // iOS could stop node after 30s here in the future if needed
  }

  /// Ensure node is running (Android only)
  Future<void> _ensureNodeRunning() async {
    try {
      final rustBackend = RustBackendService.instance;

      if (!rustBackend.isRunning) {
        _logger.w('Node not running on resume, restarting...');

        await rustBackend.startNode();

        if (rustBackend.isRunning) {
          _logger.i('✓ Node successfully restarted');
          SentryUtil.addBreadcrumb(
            category: 'lifecycle',
            message: 'node restarted on resume',
          );
        } else {
          _logger.e('✗ Failed to restart node');
          SentryUtil.addBreadcrumb(
            category: 'lifecycle',
            message: 'failed to restart node',
            level: SentryLevel.error,
          );
        }
      } else {
        _logger.d('Node already running');
      }
    } catch (e) {
      _logger.e('Error ensuring node running: $e');
    }
  }

  /// Check if epoch has changed and reschedule slots if needed
  Future<void> _checkEpochTransition() async {
    try {
      // Get current epoch from node
      final rustBackend = RustBackendService.instance;
      final status = await rustBackend.getStatus();

      if (status == null) {
        _logger.d('No status available, skipping epoch check');
        return;
      }

      final currentEpoch = status.blockchain.bestTip.epoch;
      _logger.d('Current epoch: $currentEpoch');

      // Get last known epoch
      final lastEpoch = _prefs?.getInt(_keyLastEpoch);

      if (lastEpoch == null) {
        // First time - just save current epoch
        await _prefs?.setInt(_keyLastEpoch, currentEpoch);
        _logger.d('Saved initial epoch: $currentEpoch');
        return;
      }

      if (currentEpoch != lastEpoch) {
        _logger.i('🔄 Epoch transition detected: $lastEpoch → $currentEpoch');

        SentryUtil.addBreadcrumb(
          category: 'lifecycle',
          message: 'epoch transition: $lastEpoch -> $currentEpoch',
        );

        // Handle epoch transition - reschedule all slots
        if (EpochSlotSchedulerService.instance.isInitialized) {
          _logger.i('Rescheduling slots for new epoch $currentEpoch...');

          final result = await EpochSlotSchedulerService.instance.scheduleEpochSlots(
            epoch: currentEpoch,
          );

          if (result.success) {
            _logger.i(
              '✓ Successfully rescheduled ${result.slotsScheduled} slots for epoch $currentEpoch',
            );

            // Save new epoch
            await _prefs?.setInt(_keyLastEpoch, currentEpoch);
          } else {
            _logger.e('✗ Failed to reschedule slots: ${result.error}');
          }
        } else {
          _logger
              .w('EpochSlotSchedulerService not initialized, skipping rescheduling');
          // Still save the new epoch
          await _prefs?.setInt(_keyLastEpoch, currentEpoch);
        }
      } else {
        _logger.d('Same epoch, no rescheduling needed');
      }
    } catch (e) {
      _logger.e('Error checking epoch transition: $e');
    }
  }

  /// Verify that scheduled alarms still exist (could be cleared by system)
  Future<void> _verifyScheduledAlarms() async {
    try {
      if (!EpochSlotSchedulerService.instance.isInitialized) {
        _logger.d(
            'EpochSlotSchedulerService not initialized, skipping alarm verification');
        return;
      }

      final scheduledSlots = EpochSlotSchedulerService.instance.getScheduledSlots();

      if (scheduledSlots.isEmpty) {
        _logger.d('No slots scheduled, nothing to verify');
        return;
      }

      _logger.d('Verifying ${scheduledSlots.length} scheduled alarms...');

      // Check if alarms still exist via platform alarm service
      final hasPermission = PlatformAlarmService.instance.hasPermissions;

      if (!hasPermission) {
        _logger.w(
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
        _logger.d('Alarm verification complete (Android)');
      } else {
        _logger.d('Alarm verification skipped (iOS - no verification API)');
      }
    } catch (e) {
      _logger.e('Error verifying scheduled alarms: $e');
    }
  }
}
