import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

/// Shows the OS notification dialog once per install, right after the first
/// signed-in session is ready. Later attempts are left to the SV "Set up your
/// device" sheet, which is told to re-read permissions once the dialog closes.
class StartupNotificationPrompt {
  StartupNotificationPrompt({
    Future<bool> Function()? initialize,
    Future<bool> Function()? hasPermission,
    Future<bool> Function()? requestPermission,
    VoidCallback? onPermissionsChanged,
    bool? isMobile,
  })  : _initialize = initialize ?? PlatformAlarmService.instance.initialize,
        _hasPermission = hasPermission ??
            PlatformAlarmService.instance.hasNotificationsPermission,
        _requestPermission = requestPermission ??
            PlatformAlarmService.instance.requestNotificationsPermission,
        _onPermissionsChanged = onPermissionsChanged ??
            PlatformAlarmService.instance.notifyPermissionsMayHaveChanged,
        _isMobile = isMobile ??
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS);

  static final StartupNotificationPrompt instance = StartupNotificationPrompt();

  @visibleForTesting
  static const askedKey = 'notifications:startup_prompt_asked';

  final Future<bool> Function() _initialize;
  final Future<bool> Function() _hasPermission;
  final Future<bool> Function() _requestPermission;
  final VoidCallback _onPermissionsChanged;
  final bool _isMobile;
  Future<void>? _pending;

  /// Asks for notification permission unless it is already granted or this
  /// install has asked before. Safe to call on every ready session; a call
  /// while a prompt is running joins it.
  ///
  /// Starts synchronously, so a caller that runs in the session-ready
  /// broadcast has [pending] set before SV hears the session is ready.
  Future<void> maybePrompt() {
    if (!_isMobile) return Future.value();
    return _pending ??= _run().whenComplete(() => _pending = null);
  }

  /// Completes once any running startup prompt is answered. SV's permission
  /// reads wait on it, so the "Set up your device" sheet decides from the
  /// user's answer instead of opening underneath the OS dialog.
  Future<void> get pending => _pending ?? Future.value();

  Future<void> _run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(askedKey) ?? false) return;
      // An uninitialized service would refuse the request; retry next session.
      if (!await _initialize()) return;
      final granted = await _hasPermission();
      await prefs.setBool(askedKey, true);
      if (granted) return;
      await _requestPermission();
      _onPermissionsChanged();
    } catch (e) {
      debugPrint('[StartupNotificationPrompt] failed: $e');
    }
  }
}
