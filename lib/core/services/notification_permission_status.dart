import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The OS notification permission as the trusted shell needs it: whether
/// asking can still show a dialog. The enum names ARE the bridge wire values
/// (`permissions.notificationPermission` in `getSettingsState`); renaming one
/// breaks SV.
enum NotificationPermissionStatus {
  /// Asking would show the OS dialog.
  notDetermined,

  /// Refused, or switched off in system settings. Asking shows nothing; only
  /// the OS settings page can change it.
  denied,

  /// Notifications are delivered. iOS provisional and ephemeral
  /// authorizations count, since both deliver.
  authorized;

  /// Reads a platform answer. Anything unrecognised is [notDetermined]: at
  /// worst SV then offers a request the OS answers without a dialog.
  static NotificationPermissionStatus fromWire(Object? raw) =>
      values.firstWhere((s) => s.name == raw, orElse: () => notDetermined);
}

/// Android has no "not determined" of its own: before the POST_NOTIFICATIONS
/// dialog was ever shown, and after it was refused, the permission reads the
/// same. [requestedBefore] tells the two apart.
///
/// [enabled] is `NotificationManagerCompat.areNotificationsEnabled()`, which
/// covers both the Android 13+ runtime permission and the app's switch in
/// system settings. [runtimePermission] is whether this OS has the runtime
/// permission at all (API 33+). Before it notifications are on by default,
/// so "off" can only mean the user switched them off.
NotificationPermissionStatus androidNotificationPermissionStatus({
  required bool enabled,
  required bool runtimePermission,
  required bool requestedBefore,
}) {
  if (enabled) return NotificationPermissionStatus.authorized;
  if (!runtimePermission || requestedBefore) {
    return NotificationPermissionStatus.denied;
  }
  return NotificationPermissionStatus.notDetermined;
}

/// Install-scoped record that this app has asked for notification permission.
/// Only Android reads it (see [androidNotificationPermissionStatus]); iOS
/// reports its own `notDetermined`.
class NotificationPermissionRequestLog {
  NotificationPermissionRequestLog._();

  @visibleForTesting
  static const requestedKey = 'notifications:permission_requested';

  /// Set by the prompt the app used to show on the first ready session.
  /// An install that went through it has been asked.
  @visibleForTesting
  static const legacyStartupPromptKey = 'notifications:startup_prompt_asked';

  /// Call when an OS permission dialog may have been shown.
  static Future<void> markRequested() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(requestedKey, true);
    } catch (e) {
      debugPrint('[NotificationPermission] could not record the request: $e');
    }
  }

  static Future<bool> requestedBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(requestedKey) ?? false) ||
          (prefs.getBool(legacyStartupPromptKey) ?? false);
    } catch (_) {
      return false;
    }
  }
}
