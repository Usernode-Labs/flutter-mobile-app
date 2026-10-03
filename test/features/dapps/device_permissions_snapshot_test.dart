import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/notification_permission_status.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/dapps/device_permissions_snapshot.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.onhomeroom.app/alarm');

  late PlatformAlarmService service;

  void answer(Map<String, Object?> replies) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => replies[call.method],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('iOS: carries the real OS answer next to the legacy boolean', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer({
      'hasNotificationPermission': false,
      'getNotificationAuthorizationStatus': 'denied',
    });

    expect(await devicePermissionsSnapshot(service: service), {
      'platform': 'ios',
      'exactAlarmGranted': false,
      // Kept as-is for web builds that predate `notificationPermission`; it
      // cannot tell "refused" from "never asked".
      'notificationsGranted': false,
      'notificationPermission': 'denied',
      'batteryOptDisabled': null,
      'deviceManufacturer': null,
    });
  });

  test('iOS: never asked reads notDetermined, not denied', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer({
      'hasNotificationPermission': false,
      'getNotificationAuthorizationStatus': 'notDetermined',
    });

    final snapshot = await devicePermissionsSnapshot(service: service);

    expect(snapshot['notificationsGranted'], isFalse);
    expect(snapshot['notificationPermission'], 'notDetermined');
  });

  test('android: an install that has asked reports a refusal', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({
      NotificationPermissionRequestLog.requestedKey: true,
    });
    answer({
      'hasPostNotificationsPermission': false,
      'getNotificationPermissionState': {
        'enabled': false,
        'runtimePermission': true,
      },
      'hasExactAlarmPermission': true,
      'isBatteryOptimizationDisabled': false,
    });

    final snapshot = await devicePermissionsSnapshot(service: service);

    expect(snapshot['platform'], 'android');
    expect(snapshot['exactAlarmGranted'], isTrue);
    expect(snapshot['batteryOptDisabled'], isFalse);
    expect(snapshot['notificationsGranted'], isFalse);
    expect(snapshot['notificationPermission'], 'denied');
  });

  test('getSettingsState and every settings setter carry this snapshot', () {
    final settings = File(
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
    ).readAsStringSync();
    final start = settings.indexOf('_settingsStateSnapshot({');
    final end = settings.indexOf('\n  }\n', start);
    final body = settings.substring(start, end);

    expect(body, contains('await devicePermissionsSnapshot()'));
    expect(body, contains("'permissions': permissions"));
  });
}
