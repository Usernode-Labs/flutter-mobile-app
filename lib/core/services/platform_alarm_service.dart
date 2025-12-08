import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('AlarmService');

/// Callback type for handling boot reschedule events
typedef BootRescheduleCallback = Future<void> Function();

/// Callback type for handling native block production events
typedef NativeEventCallback = void Function(
    String eventType, Map<String, dynamic> eventData);

/// Abstract interface for platform-specific alarm/wake-up scheduling
///
/// Android: Uses AlarmManager with exact alarms and Foreground Service
/// iOS: Uses BGProcessingTask and local notifications
class PlatformAlarmService {
  static final PlatformAlarmService instance = PlatformAlarmService._();
  PlatformAlarmService._();

  static const MethodChannel _channel = MethodChannel('com.usernode.app/alarm');

  bool _initialized = false;
  bool _permissionsGranted = false;

  /// Callback to invoke when device reboots and alarms need to be rescheduled
  BootRescheduleCallback? _onBootReschedule;

  /// Callback to invoke when native platform sends a block production event
  NativeEventCallback? _onNativeEvent;

  /// Initialize the platform alarm service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      _log.info(
          'PlatformAlarmService initializing for ${Platform.operatingSystem}...');

      // Set up method call handler for platform->Flutter calls
      _channel.setMethodCallHandler(_handleMethodCall);

      if (Platform.isAndroid) {
        await _initializeAndroid();
      } else if (Platform.isIOS) {
        await _initializeIOS();
      }

      _initialized = true;
      _log.info('PlatformAlarmService initialized');
      return true;
    } catch (e) {
      _log.error('Error initializing PlatformAlarmService: $e');
      return false;
    }
  }

  /// Handle method calls from platform (Android/iOS)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    _log.debug('Method call from platform: ${call.method}');

    switch (call.method) {
      case 'rescheduleAfterBoot':
        return await _handleRescheduleAfterBoot();
      case 'onBlockProductionEvent':
        return _handleNativeEvent(call.arguments);
      default:
        _log.warn('Unknown method call: ${call.method}');
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Handle a native block production event from platform code
  void _handleNativeEvent(dynamic arguments) {
    try {
      if (arguments == null) {
        _log.warn('Received null arguments for onBlockProductionEvent');
        return;
      }

      final Map<String, dynamic> args = Map<String, dynamic>.from(arguments);
      final String? eventType = args['eventType'] as String?;
      final Map<String, dynamic>? eventData = args['eventData'] != null
          ? Map<String, dynamic>.from(args['eventData'])
          : null;

      if (eventType == null) {
        _log.warn('Received native event with null eventType');
        return;
      }

      _log.debug('Native event received: $eventType');

      if (_onNativeEvent == null) {
        _log.warn('No native event callback registered for event: $eventType');
        return;
      }

      // Invoke the registered callback
      _onNativeEvent!(eventType, eventData ?? {});
    } catch (e) {
      _log.error('Error handling native event: $e');
    }
  }

  /// Set the callback to invoke when device reboots
  void setBootRescheduleCallback(BootRescheduleCallback callback) {
    _onBootReschedule = callback;
    _log.debug('Boot reschedule callback registered');
  }

  /// Set the callback to invoke when native platform sends an event
  void setNativeEventCallback(NativeEventCallback callback) {
    _onNativeEvent = callback;
    _log.debug('Native event callback registered');
  }

  /// Handle alarm rescheduling after device reboot
  Future<void> _handleRescheduleAfterBoot() async {
    try {
      _log.info(
          'Handling rescheduleAfterBoot - device rebooted, restoring alarms...');

      if (_onBootReschedule == null) {
        _log.warn('No boot reschedule callback registered!');
        return;
      }

      // Invoke the registered callback
      await _onBootReschedule!();

      _log.info('✓ Boot reschedule callback completed');
    } catch (e) {
      _log.error('Error in rescheduleAfterBoot: $e');
      rethrow;
    }
  }

  /// Initialize Android-specific alarm capabilities
  Future<void> _initializeAndroid() async {
    try {
      // Check if all required permissions are granted
      final hasNotifications =
          await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
              false;
      final hasExactAlarm =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;

      _permissionsGranted = hasNotifications && hasExactAlarm;

      if (!hasNotifications) {
        _log.warn('Android POST_NOTIFICATIONS permission not granted');
      }
      if (!hasExactAlarm) {
        _log.warn('Android exact alarm permission not granted');
      }
      if (_permissionsGranted) {
        _log.info('All Android permissions granted');
      }
    } on PlatformException catch (e) {
      _log.error('Error initializing Android alarm service: ${e.message}');
    }
  }

  /// Initialize iOS-specific background task capabilities
  Future<void> _initializeIOS() async {
    try {
      // BGTasks are already registered in AppDelegate.didFinishLaunchingWithOptions
      // Apple requires BGTaskScheduler.register() to be called BEFORE app launch completes
      // Calling it again here would violate this requirement and cause main thread blocking
      _log.info(
          'iOS background tasks already registered during app launch (AppDelegate)');

      // Just mark as ready - no need to call native code again
      _permissionsGranted = true;
      _log.info('iOS alarm service initialized successfully');
    } on PlatformException catch (e) {
      _log.error('Error initializing iOS alarm service: ${e.message}');
    }
  }

  /// Check if necessary permissions are granted
  bool get hasPermissions => _permissionsGranted;

  /// Request platform-specific permissions
  ///
  /// Android: Opens system settings for exact alarm permission
  /// iOS: Requests notification permissions (if not already granted)
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      _log.warn('Cannot request permissions: service not initialized');
      return false;
    }

    try {
      if (Platform.isAndroid) {
        return await _requestAndroidPermissions();
      } else if (Platform.isIOS) {
        return await _requestIOSPermissions();
      }
      return false;
    } catch (e) {
      _log.error('Error requesting permissions: $e');
      return false;
    }
  }

  /// Request Android permissions (POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, Battery Optimization)
  Future<bool> _requestAndroidPermissions() async {
    try {
      _log.info('Requesting Android permissions...');

      // 1. Request POST_NOTIFICATIONS first (Android 13+)
      bool hasNotifications =
          await _channel.invokeMethod<bool>('hasPostNotificationsPermission') ??
              false;

      if (!hasNotifications) {
        _log.info('Requesting POST_NOTIFICATIONS permission...');
        await _channel.invokeMethod('requestPostNotificationsPermission');
        // Wait a bit for the permission dialog to be processed
        await Future.delayed(const Duration(milliseconds: 500));
        hasNotifications = await _channel
                .invokeMethod<bool>('hasPostNotificationsPermission') ??
            false;
      }

      // 2. Request SCHEDULE_EXACT_ALARM (Android 12+)
      bool hasExactAlarm =
          await _channel.invokeMethod<bool>('hasExactAlarmPermission') ?? false;

      if (!hasExactAlarm) {
        _log.info('Requesting SCHEDULE_EXACT_ALARM permission...');
        await _channel.invokeMethod('requestExactAlarmPermission');
        // This opens settings, so we'll need to wait for user to return
        // The permission check will happen when app resumes
      }

      // 3. Request Battery Optimization Exemption
      bool hasBatteryExemption =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled') ??
              false;

      if (!hasBatteryExemption) {
        _log.info('Requesting battery optimization exemption...');
        await _channel.invokeMethod('requestBatteryOptimizationExemption');
        // This may open a dialog or settings
        await Future.delayed(const Duration(milliseconds: 500));
        hasBatteryExemption = await _channel
                .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
            false;
      }

      // Update permissions granted status
      _permissionsGranted = hasNotifications && hasExactAlarm;

      _log.info(
          'Permissions status - Notifications: $hasNotifications, Exact Alarm: $hasExactAlarm, Battery: $hasBatteryExemption');

      return _permissionsGranted;
    } on PlatformException catch (e) {
      _log.error('Error requesting Android permissions: ${e.message}');
      return false;
    }
  }

  /// Request iOS notification permissions
  Future<bool> _requestIOSPermissions() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission') ??
              false;
      _permissionsGranted = granted;

      if (granted) {
        _log.info('iOS notification permission granted');
      } else {
        _log.warn('iOS notification permission denied');
      }

      return granted;
    } on PlatformException catch (e) {
      _log.error('Error requesting iOS permissions: ${e.message}');
      return false;
    }
  }

  /// Request ONLY the Android exact alarm permission (NEW_UX onboarding step 1)
  ///
  /// On Android 12+ this opens the system settings where the user can allow
  /// exact alarms for the app. On other platforms, this returns true.
  Future<bool> requestExactAlarmOnly() async {
    if (!Platform.isAndroid) {
      return true;
    }
    if (!_initialized) {
      _log.warn('Cannot request exact alarm: service not initialized');
      return false;
    }
    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
      // Give the system a moment and then re-check
      await Future.delayed(const Duration(milliseconds: 500));
      final hasExact = await hasExactAlarmPermission();
      // Do not force notifications here; just update combined flag conservatively
      if (hasExact) {
        _log.info('Exact alarm permission granted');
      } else {
        _log.warn('Exact alarm permission still not granted');
      }
      return hasExact;
    } on PlatformException catch (e) {
      _log.error('Error requesting exact alarm permission: ${e.message}');
      return false;
    }
  }

  /// Check if POST_NOTIFICATIONS permission is granted (Android 13+)
  Future<bool> hasPostNotificationsPermission() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles notifications separately
    }

    try {
      return await _channel
              .invokeMethod<bool>('hasPostNotificationsPermission') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking POST_NOTIFICATIONS permission: ${e.message}');
      return false;
    }
  }

  /// Check if SCHEDULE_EXACT_ALARM permission is granted (Android 12+)
  Future<bool> hasExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasExactAlarmPermission') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking exact alarm permission: ${e.message}');
      return false;
    }
  }

  /// Request battery optimization exemption
  Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't have this concept
    }

    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
      // Check if exemption was granted
      await Future.delayed(const Duration(milliseconds: 500));
      return await isBatteryOptimizationDisabled();
    } on PlatformException catch (e) {
      _log.error(
          'Error requesting battery optimization exemption: ${e.message}');
      return false;
    }
  }

  /// Schedule an exact alarm for a specific time
  ///
  /// Android: Schedules exact alarm + starts Foreground Service
  /// iOS: Schedules BGProcessingTask + local notification
  Future<bool> scheduleAlarm({
    required String alarmId,
    required DateTime alarmTime,
    required int slotNumber,
    Map<String, dynamic>? data,
  }) async {
    if (!_initialized) {
      _log.warn('Cannot schedule alarm: service not initialized');
      return false;
    }

    if (!_permissionsGranted) {
      _log.warn('Cannot schedule alarm: permissions not granted');
      return false;
    }

    try {
      final params = {
        'alarmId': alarmId,
        'alarmTimeMs': alarmTime.millisecondsSinceEpoch,
        'slotNumber': slotNumber,
        'data': data ?? {},
      };

      if (Platform.isAndroid) {
        return await _scheduleAndroidAlarm(params);
      } else if (Platform.isIOS) {
        return await _scheduleIOSAlarm(params);
      }

      return false;
    } catch (e) {
      _log.error('Error scheduling alarm: $e');
      return false;
    }
  }

  /// Schedule Android exact alarm
  Future<bool> _scheduleAndroidAlarm(Map<String, dynamic> params) async {
    try {
      final success =
          await _channel.invokeMethod<bool>('scheduleExactAlarm', params) ??
              false;

      if (success) {
        _log.info(
            'Android exact alarm scheduled for slot ${params['slotNumber']}');
      } else {
        _log.warn('Failed to schedule Android exact alarm');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error scheduling Android alarm: ${e.message}');
      return false;
    }
  }

  /// Schedule iOS background task and notification
  Future<bool> _scheduleIOSAlarm(Map<String, dynamic> params) async {
    try {
      final success =
          await _channel.invokeMethod<bool>('scheduleIOSBGTask', params) ??
              false;

      if (success) {
        _log.info('iOS BGTask scheduled for slot ${params['slotNumber']}');
      } else {
        _log.warn('Failed to schedule iOS BGTask');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error scheduling iOS BGTask: ${e.message}');
      return false;
    }
  }

  /// Cancel a specific alarm
  Future<bool> cancelAlarm(String alarmId) async {
    if (!_initialized) {
      _log.warn('Cannot cancel alarm: service not initialized');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('cancelAlarm', {'alarmId': alarmId}) ??
          false;

      if (success) {
        _log.debug('Alarm cancelled: $alarmId');
      } else {
        _log.warn('Failed to cancel alarm: $alarmId');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error cancelling alarm: ${e.message}');
      return false;
    }
  }

  /// Cancel all scheduled alarms
  Future<bool> cancelAllAlarms() async {
    if (!_initialized) {
      _log.warn('Cannot cancel alarms: service not initialized');
      return false;
    }

    try {
      final success =
          await _channel.invokeMethod<bool>('cancelAllAlarms') ?? false;

      if (success) {
        _log.info('All alarms cancelled');
      } else {
        _log.warn('Failed to cancel all alarms');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error cancelling all alarms: ${e.message}');
      return false;
    }
  }

  /// Start foreground service (Android only)
  ///
  /// This must be called when an alarm fires to keep the app running
  /// during block production monitoring.
  Future<bool> startForegroundService({
    required String title,
    required String message,
    required int slotNumber,
  }) async {
    if (!Platform.isAndroid) {
      _log.debug('Foreground service is Android-only');
      return false;
    }

    try {
      final params = {
        'title': title,
        'message': message,
        'slotNumber': slotNumber,
      };

      final success =
          await _channel.invokeMethod<bool>('startForegroundService', params) ??
              false;

      if (success) {
        _log.info('Foreground service started for slot $slotNumber');
      } else {
        _log.warn('Failed to start foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error starting foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop foreground service (Android only)
  Future<bool> stopForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Foreground service is Android-only');
      return false;
    }

    try {
      final success =
          await _channel.invokeMethod<bool>('stopForegroundService') ?? false;

      if (success) {
        _log.info('Foreground service stopped');
      } else {
        _log.warn('Failed to stop foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error stopping foreground service: ${e.message}');
      return false;
    }
  }

  /// Start persistent foreground service (Android only)
  ///
  /// This keeps the app running continuously in the foreground,
  /// providing 100% reliability for block production monitoring
  /// at the cost of higher battery usage.
  Future<bool> startPersistentForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Persistent foreground service is Android-only');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('startPersistentForegroundService') ??
          false;

      if (success) {
        _log.info('Persistent foreground service started');
      } else {
        _log.warn('Failed to start persistent foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error starting persistent foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop persistent foreground service (Android only)
  Future<bool> stopPersistentForegroundService() async {
    if (!Platform.isAndroid) {
      _log.debug('Persistent foreground service is Android-only');
      return false;
    }

    try {
      final success = await _channel
              .invokeMethod<bool>('stopPersistentForegroundService') ??
          false;

      if (success) {
        _log.info('Persistent foreground service stopped');
      } else {
        _log.warn('Failed to stop persistent foreground service');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error stopping persistent foreground service: ${e.message}');
      return false;
    }
  }

  /// Check if persistent foreground service is running (Android only)
  Future<bool> isPersistentForegroundRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final isRunning =
          await _channel.invokeMethod<bool>('isPersistentForegroundRunning');
      return isRunning ?? false;
    } catch (e) {
      _log.error('Error checking persistent foreground status: $e');
      return false;
    }
  }

  /// Open battery optimization settings
  ///
  /// Helps users exempt the app from battery optimization on OEM devices.
  Future<bool> openBatteryOptimizationSettings() async {
    try {
      final success =
          await _channel.invokeMethod<bool>('openBatterySettings') ?? false;

      if (success) {
        _log.info('Opened battery optimization settings');
      } else {
        _log.warn('Failed to open battery optimization settings');
      }

      return success;
    } on PlatformException catch (e) {
      _log.error('Error opening battery settings: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is disabled for this app
  Future<bool> isBatteryOptimizationDisabled() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't have this concept
    }

    try {
      return await _channel
              .invokeMethod<bool>('isBatteryOptimizationDisabled') ??
          false;
    } on PlatformException catch (e) {
      _log.error('Error checking battery optimization: ${e.message}');
      return false;
    }
  }

  /// Get OEM device manufacturer
  ///
  /// Useful for providing OEM-specific guidance (Xiaomi, Samsung, Oppo, etc.)
  Future<String?> getDeviceManufacturer() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      return await _channel.invokeMethod<String>('getDeviceManufacturer');
    } on PlatformException catch (e) {
      _log.error('Error getting device manufacturer: ${e.message}');
      return null;
    }
  }

  /// Check if foreground service is currently running (Android only)
  Future<bool> isForegroundServiceRunning() async {
    if (!Platform.isAndroid) return false;
    try {
      final isRunning =
          await _channel.invokeMethod<bool>('isForegroundServiceRunning');
      return isRunning ?? false;
    } catch (e) {
      _log.error('Error checking foreground service status: $e');
      return false;
    }
  }

  /// Check if wakelock is currently held (Android only)
  Future<bool> isWakelockHeld() async {
    if (!Platform.isAndroid) return false;
    try {
      final isHeld = await _channel.invokeMethod<bool>('isWakelockHeld');
      return isHeld ?? false;
    } catch (e) {
      _log.error('Error checking wakelock status: $e');
      return false;
    }
  }

  /// Get background task execution statistics (Android only)
  Future<Map<String, dynamic>> getBackgroundTaskStats() async {
    if (!Platform.isAndroid) {
      return {
        'execution_count': 0,
        'last_execution_time': 0,
        'success_count': 0,
        'failure_count': 0,
      };
    }
    try {
      final stats = await _channel.invokeMethod<Map>('getBackgroundTaskStats');
      return Map<String, dynamic>.from(stats ?? {});
    } catch (e) {
      _log.error('Error getting background task stats: $e');
      return {
        'execution_count': 0,
        'last_execution_time': 0,
        'success_count': 0,
        'failure_count': 0,
      };
    }
  }

  /// Increment background task execution count (Android only)
  Future<void> incrementBackgroundTaskCount() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('incrementBackgroundTaskCount');
    } catch (e) {
      _log.error('Error incrementing background task count: $e');
    }
  }
}

/// Result of an alarm scheduling operation
class AlarmScheduleResult {
  final bool success;
  final String? error;
  final bool needsPermission;
  final bool needsBatteryOptDisabled;

  AlarmScheduleResult({
    required this.success,
    this.error,
    this.needsPermission = false,
    this.needsBatteryOptDisabled = false,
  });
}
