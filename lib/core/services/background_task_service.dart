import 'package:workmanager/workmanager.dart';
import 'package:logger/logger.dart';
import '../config/notification_config.dart';
import '../data/notification_state_repository.dart';
import 'local_notification_service.dart';

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
        existingWorkPolicy: ExistingWorkPolicy.replace,
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

      // Check if notifications are enabled
      if (!NotificationStateRepository.instance.notificationsEnabled) {
        logger.d('Notifications disabled, skipping background task');
        return Future.value(true);
      }

      // Perform the background slot monitoring
      await _performSlotMonitoring(logger);

      logger.i('Background task completed successfully');
      return Future.value(true);
    } catch (e) {
      logger.e('Background task failed: $e');
      return Future.value(false);
    }
  });
}

/// Perform slot monitoring in background
Future<void> _performSlotMonitoring(Logger logger) async {
  try {
    // Get current epoch rewards data from Rust backend
    // Note: This requires the Rust backend to be running, which may not be
    // the case in background. For a hybrid approach, we'll try but fail gracefully.
    // Try to get current epoch (this might fail if Rust backend is not running)
    // In a production app, you might want to store the current epoch in SharedPreferences
    // and use that as a fallback

    logger.d('Attempting to fetch epoch data in background');

    // For now, we'll clean up old notifications and let the foreground
    // handle the actual scheduling when the app is active
    await NotificationStateRepository.instance.cleanupOldNotifications();

    logger.d('Cleaned up old notifications in background');

    // TODO: Implement more sophisticated background monitoring
    // This could include:
    // 1. Storing epoch data in local storage when app is active
    // 2. Using that stored data to check for missed slots
    // 3. Sending notifications for missed slots
    // 4. Re-scheduling upcoming notifications if they were cancelled
  } catch (e) {
    logger.e('Error in background slot monitoring: $e');
    // Don't throw - we want the task to complete even if there's an error
  }
}
