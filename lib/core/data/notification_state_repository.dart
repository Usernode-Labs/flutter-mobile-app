import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import '../config/notification_config.dart';

/// Repository for managing notification state and settings
class NotificationStateRepository {
  static final NotificationStateRepository instance =
      NotificationStateRepository._();
  NotificationStateRepository._();

  final Logger _logger = Logger();
  SharedPreferences? _prefs;

  /// Initialize the repository
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _logger.d('NotificationStateRepository initialized');
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('NotificationStateRepository not initialized');
    }
    return _prefs!;
  }

  // ===== Notification Settings =====

  /// Check if notifications are globally enabled
  bool get notificationsEnabled {
    return _preferences.getBool(NotificationConfig.prefKeyNotificationsEnabled) ??
        NotificationConfig.defaultNotificationsEnabled;
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(
        NotificationConfig.prefKeyNotificationsEnabled, enabled);
    _logger.d('Notifications enabled: $enabled');
  }

  /// Check if upcoming slot notifications are enabled
  bool get upcomingNotificationsEnabled {
    return _preferences.getBool(NotificationConfig.prefKeyUpcomingEnabled) ??
        NotificationConfig.defaultUpcomingEnabled;
  }

  /// Set upcoming notifications enabled/disabled
  Future<void> setUpcomingNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(NotificationConfig.prefKeyUpcomingEnabled, enabled);
    _logger.d('Upcoming notifications enabled: $enabled');
  }

  /// Check if produced block notifications are enabled
  bool get producedNotificationsEnabled {
    return _preferences.getBool(NotificationConfig.prefKeyProducedEnabled) ??
        NotificationConfig.defaultProducedEnabled;
  }

  /// Set produced notifications enabled/disabled
  Future<void> setProducedNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(NotificationConfig.prefKeyProducedEnabled, enabled);
    _logger.d('Produced notifications enabled: $enabled');
  }

  /// Check if missed slot notifications are enabled
  bool get missedNotificationsEnabled {
    return _preferences.getBool(NotificationConfig.prefKeyMissedEnabled) ??
        NotificationConfig.defaultMissedEnabled;
  }

  /// Set missed notifications enabled/disabled
  Future<void> setMissedNotificationsEnabled(bool enabled) async {
    await _preferences.setBool(NotificationConfig.prefKeyMissedEnabled, enabled);
    _logger.d('Missed notifications enabled: $enabled');
  }

  /// Get advance warning time in minutes
  int get advanceWarningMinutes {
    return _preferences.getInt(NotificationConfig.prefKeyAdvanceWarningMinutes) ??
        NotificationConfig.defaultAdvanceWarningMinutes;
  }

  /// Set advance warning time
  Future<void> setAdvanceWarningMinutes(int minutes) async {
    await _preferences.setInt(
        NotificationConfig.prefKeyAdvanceWarningMinutes, minutes);
    _logger.d('Advance warning time: $minutes minutes');
  }

  /// Check if smart batching is enabled
  bool get smartBatchingEnabled {
    return _preferences.getBool(NotificationConfig.prefKeySmartBatchingEnabled) ??
        NotificationConfig.defaultSmartBatchingEnabled;
  }

  /// Set smart batching enabled/disabled
  Future<void> setSmartBatchingEnabled(bool enabled) async {
    await _preferences.setBool(
        NotificationConfig.prefKeySmartBatchingEnabled, enabled);
    _logger.d('Smart batching enabled: $enabled');
  }

  // ===== Scheduled Notifications Tracking =====

  /// Get all scheduled notifications
  List<ScheduledNotification> getScheduledNotifications() {
    try {
      final jsonString =
          _preferences.getString(NotificationConfig.prefKeyScheduledNotifications);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => ScheduledNotification.fromJson(json))
          .toList();
    } catch (e) {
      _logger.e('Error loading scheduled notifications: $e');
      return [];
    }
  }

  /// Save scheduled notifications
  Future<void> saveScheduledNotifications(
      List<ScheduledNotification> notifications) async {
    try {
      final jsonList = notifications.map((n) => n.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _preferences.setString(
          NotificationConfig.prefKeyScheduledNotifications, jsonString);
      _logger.d('Saved ${notifications.length} scheduled notifications');
    } catch (e) {
      _logger.e('Error saving scheduled notifications: $e');
    }
  }

  /// Add a scheduled notification to tracking
  Future<void> addScheduledNotification(ScheduledNotification notification) async {
    final notifications = getScheduledNotifications();

    // Don't add duplicates
    if (notifications.any((n) =>
        n.notificationId == notification.notificationId ||
        (n.globalSlot == notification.globalSlot && n.type == notification.type))) {
      _logger.d('Notification already scheduled: ${notification.globalSlot}');
      return;
    }

    notifications.add(notification);
    await saveScheduledNotifications(notifications);
  }

  /// Remove a scheduled notification from tracking
  Future<void> removeScheduledNotification(int notificationId) async {
    final notifications = getScheduledNotifications();
    notifications.removeWhere((n) => n.notificationId == notificationId);
    await saveScheduledNotifications(notifications);
    _logger.d('Removed notification: $notificationId');
  }

  /// Remove all scheduled notifications for a specific slot
  Future<void> removeScheduledNotificationsForSlot(int globalSlot) async {
    final notifications = getScheduledNotifications();
    notifications.removeWhere((n) => n.globalSlot == globalSlot);
    await saveScheduledNotifications(notifications);
    _logger.d('Removed all notifications for slot: $globalSlot');
  }

  /// Clear all scheduled notifications
  Future<void> clearScheduledNotifications() async {
    await _preferences.remove(NotificationConfig.prefKeyScheduledNotifications);
    _logger.d('Cleared all scheduled notifications');
  }

  /// Clean up outdated scheduled notifications (older than 24 hours)
  Future<void> cleanupOldNotifications() async {
    final notifications = getScheduledNotifications();
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));

    final activeNotifications = notifications.where((n) {
      return n.slotTime.isAfter(cutoffTime);
    }).toList();

    if (activeNotifications.length != notifications.length) {
      await saveScheduledNotifications(activeNotifications);
      _logger.d(
          'Cleaned up ${notifications.length - activeNotifications.length} old notifications');
    }
  }

  /// Get scheduled notifications for a specific slot
  List<ScheduledNotification> getScheduledNotificationsForSlot(int globalSlot) {
    return getScheduledNotifications()
        .where((n) => n.globalSlot == globalSlot)
        .toList();
  }

  /// Check if a notification is already scheduled
  bool isNotificationScheduled({
    required int globalSlot,
    required SlotNotificationType type,
  }) {
    return getScheduledNotifications().any(
      (n) => n.globalSlot == globalSlot && n.type == type,
    );
  }

  /// Get count of scheduled notifications
  int get scheduledNotificationCount {
    return getScheduledNotifications().length;
  }

  /// Get statistics about scheduled notifications
  Map<SlotNotificationType, int> getNotificationStats() {
    final notifications = getScheduledNotifications();
    final stats = <SlotNotificationType, int>{};

    for (final type in SlotNotificationType.values) {
      stats[type] = notifications.where((n) => n.type == type).length;
    }

    return stats;
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    await setNotificationsEnabled(NotificationConfig.defaultNotificationsEnabled);
    await setUpcomingNotificationsEnabled(
        NotificationConfig.defaultUpcomingEnabled);
    await setProducedNotificationsEnabled(
        NotificationConfig.defaultProducedEnabled);
    await setMissedNotificationsEnabled(NotificationConfig.defaultMissedEnabled);
    await setAdvanceWarningMinutes(
        NotificationConfig.defaultAdvanceWarningMinutes);
    await setSmartBatchingEnabled(
        NotificationConfig.defaultSmartBatchingEnabled);
    await clearScheduledNotifications();
    _logger.i('Reset notification settings to defaults');
  }
}
