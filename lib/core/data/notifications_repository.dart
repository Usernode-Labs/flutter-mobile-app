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
      Log.d('NOTIFICATIONS_REPO', 'Saved ${toSave.length} notifications');
    } catch (e, st) {
      Log.e('NOTIFICATIONS_REPO', 'Failed to save notifications', e, st);
    }
  }

  /// Load notifications from persistent storage
  Future<List<AppNotification>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keyNotifications);

      if (jsonString == null || jsonString.isEmpty) {
        Log.d('NOTIFICATIONS_REPO', 'No saved notifications found');
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final notifications = jsonList
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      Log.d('NOTIFICATIONS_REPO', 'Loaded ${notifications.length} notifications');
      return notifications;
    } catch (e, st) {
      Log.e('NOTIFICATIONS_REPO', 'Failed to load notifications', e, st);
      return [];
    }
  }

  /// Clear all notifications
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotifications);
      Log.d('NOTIFICATIONS_REPO', 'Cleared all notifications');
    } catch (e, st) {
      Log.e('NOTIFICATIONS_REPO', 'Failed to clear notifications', e, st);
    }
  }
}
