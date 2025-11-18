import 'dart:io';
import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';
import '../config/notification_config.dart';
import '../data/notification_state_repository.dart';
import 'local_notification_service.dart';
import 'slot_notification_manager.dart';
import 'platform_alarm_service.dart';
import '../../features/node/data/repositories/rust_backend_service.dart';

/// Background task service for monitoring slots when app is not in foreground
class BackgroundTaskService {
  static final BackgroundTaskService instance = BackgroundTaskService._();
  BackgroundTaskService._();

  final Logger _logger = Logger();
  bool _initialized = false;

  /// Initialize the background task service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true during development to see logs
      );

      _initialized = true;
      _logger.i('BackgroundTaskService initialized');
      return true;
    } catch (e) {
      _logger.e('Error initializing BackgroundTaskService: $e');
      return false;
    }
  }

  /// Register periodic task for slot monitoring
  Future<void> registerSlotMonitoringTask() async {
    if (!_initialized) {
      _logger.w('Cannot register task: service not initialized');
      return;
    }

    try {
      // iOS has different background task behavior
      if (Platform.isIOS) {
        _logger.i(
          'Registering background task for iOS (Note: Frequency is best-effort, '
          'iOS system decides when to run based on device usage patterns)',
        );
      }

      await Workmanager().registerPeriodicTask(
        NotificationConfig.backgroundTaskName,
        NotificationConfig.backgroundTaskName,
        frequency: NotificationConfig.backgroundTaskFrequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      _logger.i('Slot monitoring task registered');
    } catch (e) {
      _logger.e('Error registering slot monitoring task: $e');
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    try {
      await Workmanager().cancelAll();
      _logger.i('All background tasks cancelled');
    } catch (e) {
      _logger.e('Error cancelling tasks: $e');
    }
  }

  /// Cancel specific task
  Future<void> cancelTask(String taskName) async {
    try {
      await Workmanager().cancelByUniqueName(taskName);
      _logger.i('Task cancelled: $taskName');
    } catch (e) {
      _logger.e('Error cancelling task: $e');
    }
  }
}

/// Background callback dispatcher - this runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final logger = Logger();
    logger.i('Background task started: $task');

    try {
      // Initialize required services in the background isolate
      await NotificationStateRepository.instance.initialize();
      await LocalNotificationService.instance.initialize();

      // Initialize platform alarm service for metrics tracking
      await PlatformAlarmService.instance.initialize();

      // Check if notifications are enabled
      if (!NotificationStateRepository.instance.notificationsEnabled) {
        logger.d('Notifications disabled, skipping background task');
        // Still increment counter to track execution
        await PlatformAlarmService.instance.incrementBackgroundTaskCount();
        return Future.value(true);
      }

      // Perform the background slot monitoring
      await _performSlotMonitoring(logger);

      // Track successful background task execution
      await PlatformAlarmService.instance.incrementBackgroundTaskCount();

      logger.i('Background task completed successfully');
      return Future.value(true);
    } catch (e) {
      logger.e('Background task failed: $e');

      // Track failed background task execution
      try {
        await PlatformAlarmService.instance.incrementBackgroundTaskCount();
      } catch (_) {
        // Ignore if metrics tracking fails
      }

      return Future.value(false);
    }
  });
}

/// Perform slot monitoring in background
Future<void> _performSlotMonitoring(Logger logger) async {
  try {
    logger.d('Background slot monitoring started');

    // Always clean up old notifications first
    await NotificationStateRepository.instance.cleanupOldNotifications();
    logger.d('Cleaned up old notifications');

    // Try to fetch latest epoch data from Rust backend
    // This will only work if backend is running in background
    try {
      final rustBackend = RustBackendService.instance;

      // Get current status to determine epoch
      final status = await rustBackend.getStatus();
      if (status == null) {
        logger.d('Background: No status available from Rust backend');
        return;
      }

      final currentEpoch = status.blockchain.bestTip.epoch;
      logger.d('Background: Current epoch is $currentEpoch');

      // Fetch epoch rewards for current epoch
      final rewards = await rustBackend.epochRewards(epoch: currentEpoch);
      if (rewards == null ||
          rewards.wonSlots == null ||
          rewards.wonSlots!.isEmpty) {
        logger.d('Background: No won slots for epoch $currentEpoch');
        return;
      }

      logger.i(
          'Background: Found ${rewards.wonSlots!.length} won slots for epoch $currentEpoch');

      // Check for epoch change
      final stateRepo = NotificationStateRepository.instance;
      final previousEpoch = stateRepo.currentEpoch;

      if (previousEpoch != null && previousEpoch != currentEpoch) {
        logger.i(
            'Background: Epoch changed from $previousEpoch to $currentEpoch');
        // Cancel old notifications from previous epoch
        await LocalNotificationService.instance.cancelAllNotifications();
        await stateRepo.clearScheduledNotifications();
        await stateRepo.setCurrentEpoch(currentEpoch);
      }

      // Get produced slots from blockchain
      final blockchain = await rustBackend.listBlockchain(
        limit: 100,
        fromTip: true,
        epoch: currentEpoch,
      );

      final producedSlots = <int>{};
      if (blockchain?.items != null) {
        for (final block in blockchain!.items) {
          producedSlots.add(block.globalSlot);
        }
      }

      logger.d('Background: Found ${producedSlots.length} produced slots');

      // Schedule notifications for upcoming slots
      await SlotNotificationManager.instance.scheduleNotificationsForSlots(
        wonSlots: rewards.wonSlots!,
        producedSlots: producedSlots,
        epoch: currentEpoch,
        rewardPerBlock: rewards.rewardPerBlock,
      );

      logger.i(
          'Background: Successfully scheduled notifications for epoch $currentEpoch');
    } on Exception catch (e) {
      logger.w('Background: Rust backend not available or failed: $e');
      // This is expected when app is fully closed - backend may not be running
      // Notifications will be rescheduled when app opens and foreground runs
    }
  } catch (e, st) {
    logger.e('Background slot monitoring error: $e', error: e, stackTrace: st);
    // Don't throw - we want the task to complete even if there's an error
  }
}
