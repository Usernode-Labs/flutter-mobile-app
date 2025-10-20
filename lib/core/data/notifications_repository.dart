import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/models/app_notification.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

/// Repository for managing notification persistence
class NotificationsRepository {
  static const String _keyNotifications = 'app_notifications';
  static const int _maxNotifications = 100;

  /// Save notifications to persistent storage
  Future<void> save(List<AppNotification> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Keep only the most recent notifications
      final toSave = notifications.length > _maxNotifications
          ? notifications.sublist(0, _maxNotifications)
          : notifications;

      final jsonList = toSave.map((n) => n.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await prefs.setString(_keyNotifications, jsonString);
      LoggingService.instance.debug('Saved ${toSave.length} notifications',
          tag: 'NOTIFICATIONS_REPO');
    } catch (e, st) {
      LoggingService.instance.error('Failed to save notifications',
          tag: 'NOTIFICATIONS_REPO', error: e, stackTrace: st);
    }
  }

  /// Load notifications from persistent storage
  Future<List<AppNotification>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyNotifications);

      if (jsonString == null || jsonString.isEmpty) {
        LoggingService.instance
            .debug('No saved notifications found', tag: 'NOTIFICATIONS_REPO');
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final notifications = jsonList
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      LoggingService.instance.debug(
          'Loaded ${notifications.length} notifications',
          tag: 'NOTIFICATIONS_REPO');
      return notifications;
    } catch (e, st) {
      LoggingService.instance.error('Failed to load notifications',
          tag: 'NOTIFICATIONS_REPO', error: e, stackTrace: st);
      return [];
    }
  }

  /// Clear all notifications
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotifications);
      LoggingService.instance
          .debug('Cleared all notifications', tag: 'NOTIFICATIONS_REPO');
    } catch (e, st) {
      LoggingService.instance.error('Failed to clear notifications',
          tag: 'NOTIFICATIONS_REPO', error: e, stackTrace: st);
    }
  }
}
