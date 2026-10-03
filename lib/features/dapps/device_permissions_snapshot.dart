import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/services/notification_permission_status.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

/// The `permissions` object of the bridge's `getSettingsState` snapshot.
///
/// Live probes, not the service's cached combined flag: the granular request
/// methods don't refresh `hasPermissions`, and its legacy
/// notifications&&exactAlarm semantics would mislabel `exactAlarmGranted`.
///
/// `notificationPermission` is the OS answer SV needs before it asks:
/// `notDetermined` (asking shows the dialog), `denied` (only Settings can
/// help) or `authorized`. It comes from the platform, not Firebase, so builds
/// without push report it too. `notificationsGranted` stays for web builds
/// that predate it.
Future<Map<String, Object?>> devicePermissionsSnapshot({
  PlatformAlarmService? service,
}) async {
  final alarms = service ?? PlatformAlarmService.instance;
  final isAndroid = defaultTargetPlatform == TargetPlatform.android;
  bool exactAlarmGranted = false;
  bool? batteryOptDisabled;
  bool notificationsGranted = false;
  var notificationPermission = NotificationPermissionStatus.notDetermined;
  String? deviceManufacturer;
  try {
    await alarms.initialize();
    notificationsGranted = await alarms.hasNotificationsPermission();
    notificationPermission = await alarms.notificationPermissionStatus();
    final alarm = await alarms.alarmPermissionsSnapshot();
    exactAlarmGranted = alarm['exactAlarmGranted'] == true;
    batteryOptDisabled = alarm['batteryOptDisabled'] as bool?;
    if (isAndroid) {
      deviceManufacturer = await alarms.getDeviceManufacturer();
    }
  } catch (e) {
    debugPrint('[Usernode JS-channel] permission probe failed: $e');
  }
  return {
    'platform': isAndroid ? 'android' : 'ios',
    'exactAlarmGranted': exactAlarmGranted,
    'notificationsGranted': notificationsGranted,
    'notificationPermission': notificationPermission.name,
    'batteryOptDisabled': batteryOptDisabled,
    'deviceManufacturer': deviceManufacturer,
  };
}
