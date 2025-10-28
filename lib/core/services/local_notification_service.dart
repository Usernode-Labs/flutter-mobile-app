import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../config/notification_config.dart';

/// Service for managing local (native) notifications
class LocalNotificationService {
  static final LocalNotificationService instance = LocalNotificationService._();
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Logger _logger = Logger();
  bool _initialized = false;

  /// Initialize the notification service
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        await _createNotificationChannels();
        _initialized = true;
        _logger.i('LocalNotificationService initialized successfully');
        return true;
      }

      _logger.w('Failed to initialize LocalNotificationService');
      return false;
    } catch (e) {
      _logger.e('Error initializing notifications: $e');
      return false;
    }
  }

  /// Request notification permissions (required for Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          _logger.i('Android notification permission: $granted');
          return granted ?? false;
        }
      } else if (Platform.isIOS) {
        final iosPlugin = _notifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          _logger.i('iOS notification permission: $granted');
          return granted ?? false;
        }
      }
      return false;
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      return false;
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // High-priority channel for slot notifications
    const slotChannel = AndroidNotificationChannel(
      NotificationConfig.slotChannelId,
      NotificationConfig.slotChannelName,
      description: NotificationConfig.slotChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Normal priority channel for general notifications
    const generalChannel = AndroidNotificationChannel(
      NotificationConfig.generalChannelId,
      NotificationConfig.generalChannelName,
      description: NotificationConfig.generalChannelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(slotChannel);
    await androidPlugin.createNotificationChannel(generalChannel);
    _logger.d('Notification channels created');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _logger.d('Notification tapped: ${response.id}, payload: ${response.payload}');
    // TODO: Navigate to appropriate screen based on payload
    // This can be extended to parse payload and navigate using go_router
  }

  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isSlotNotification = false,
  }) async {
    if (!_initialized) {
      _logger.w('Cannot show notification: service not initialized');
      return;
    }

    try {
      final channelId = isSlotNotification
          ? NotificationConfig.slotChannelId
          : NotificationConfig.generalChannelId;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        isSlotNotification
            ? NotificationConfig.slotChannelName
            : NotificationConfig.generalChannelName,
        channelDescription: isSlotNotification
            ? NotificationConfig.slotChannelDescription
            : NotificationConfig.generalChannelDescription,
        importance: isSlotNotification ? Importance.high : Importance.defaultImportance,
        priority: isSlotNotification ? Priority.high : Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(id, title, body, details, payload: payload);
      _logger.d('Notification shown: $title');
    } catch (e) {
      _logger.e('Error showing notification: $e');
    }
  }

  /// Schedule a notification for a future time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    bool isSlotNotification = false,
  }) async {
    if (!_initialized) {
      _logger.w('Cannot schedule notification: service not initialized');
      return;
    }

    // Don't schedule notifications in the past
    if (scheduledTime.isBefore(DateTime.now())) {
      _logger.w('Cannot schedule notification in the past: $scheduledTime');
      return;
    }

    try {
      final channelId = isSlotNotification
          ? NotificationConfig.slotChannelId
          : NotificationConfig.generalChannelId;

      final androidDetails = AndroidNotificationDetails(
        channelId,
        isSlotNotification
            ? NotificationConfig.slotChannelName
            : NotificationConfig.generalChannelName,
        channelDescription: isSlotNotification
            ? NotificationConfig.slotChannelDescription
            : NotificationConfig.generalChannelDescription,
        importance: isSlotNotification ? Importance.high : Importance.defaultImportance,
        priority: isSlotNotification ? Priority.high : Priority.defaultPriority,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      _logger.d('Notification scheduled: $title at $scheduledTime');
    } catch (e) {
      _logger.e('Error scheduling notification: $e');
    }
  }

  /// Cancel a scheduled notification
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      _logger.d('Notification cancelled: $id');
    } catch (e) {
      _logger.e('Error cancelling notification: $e');
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
      _logger.d('All notifications cancelled');
    } catch (e) {
      _logger.e('Error cancelling all notifications: $e');
    }
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notifications.pendingNotificationRequests();
    } catch (e) {
      _logger.e('Error getting pending notifications: $e');
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final settings = await iosPlugin?.getNotificationAppLaunchDetails();
      return settings?.didNotificationLaunchApp ?? false;
    }
    return false;
  }
}
