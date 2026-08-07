import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.usernode.app/alarm');

  late List<String> calls;
  late Map<String, List<Object?>> responses;
  late PlatformAlarmService service;

  Future<void> setUpService() async {
    calls = [];
    responses = {};
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      final queue = responses[call.method];
      if (queue == null || queue.isEmpty) return null;
      return queue.removeAt(0);
    });
    service = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
    );
    await service.initialize();
  }

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('requestAlarmPermissions', () {
    test('android: runs exact-alarm + battery chain, never notifications',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [false];
      responses['isBatteryOptimizationDisabled'] = [false, true];

      final granted = await service.requestAlarmPermissions();

      // Exact-alarm grants happen in system settings, so the result reflects
      // the pre-request state; the re-check happens on app resume.
      expect(granted, isFalse);
      expect(calls, contains('requestExactAlarmPermission'));
      expect(calls, contains('requestBatteryOptimizationExemption'));
      expect(calls, isNot(contains('hasPostNotificationsPermission')));
      expect(calls, isNot(contains('requestPostNotificationsPermission')));
      expect(calls, isNot(contains('requestNotificationPermission')));
    });

    test('android: exact alarm granted, battery pending -> true', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [false, true];

      final granted = await service.requestAlarmPermissions();

      expect(granted, isTrue);
      expect(calls, isNot(contains('requestExactAlarmPermission')));
      expect(calls, contains('requestBatteryOptimizationExemption'));
    });

    test('android: already granted -> no request calls', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [true];

      final granted = await service.requestAlarmPermissions();

      expect(granted, isTrue);
      expect(calls, isNot(contains('requestExactAlarmPermission')));
      expect(calls, isNot(contains('requestBatteryOptimizationExemption')));
    });

    test('iOS: not applicable -> true without channel traffic', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();

      final granted = await service.requestAlarmPermissions();

      expect(granted, isTrue);
      expect(calls, isEmpty);
    });
  });

  group('requestNotificationsPermission', () {
    test('android: POST_NOTIFICATIONS chain only', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, true];

      final granted = await service.requestNotificationsPermission();

      expect(granted, isTrue);
      expect(calls, contains('requestPostNotificationsPermission'));
      expect(calls, isNot(contains('hasExactAlarmPermission')));
      expect(calls, isNot(contains('isBatteryOptimizationDisabled')));
    });

    test('iOS: delegates to requestNotificationPermission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();
      responses['requestNotificationPermission'] = [true];

      final granted = await service.requestNotificationsPermission();

      expect(granted, isTrue);
      expect(calls, ['requestNotificationPermission']);
    });
  });

  group('hasNotificationsPermission', () {
    test('android probes hasPostNotificationsPermission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasPostNotificationsPermission'] = [true];

      expect(await service.hasNotificationsPermission(), isTrue);
      expect(calls, ['hasPostNotificationsPermission']);
    });

    test('iOS probes hasNotificationPermission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();
      responses['hasNotificationPermission'] = [false];

      expect(await service.hasNotificationsPermission(), isFalse);
      expect(calls, ['hasNotificationPermission']);
    });
  });

  group('openNotificationSettings', () {
    test('invokes the channel method', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['openNotificationSettings'] = [true];

      expect(await service.openNotificationSettings(), isTrue);
      expect(calls, ['openNotificationSettings']);
    });
  });

  group('alarmPermissionsSnapshot', () {
    test('android: probes both states', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [false];

      final snapshot = await service.alarmPermissionsSnapshot();

      expect(snapshot, {
        'applicable': true,
        'exactAlarmGranted': true,
        'batteryOptDisabled': false,
      });
    });

    test('iOS: not applicable, null states, no channel traffic', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();

      final snapshot = await service.alarmPermissionsSnapshot();

      expect(snapshot, {
        'applicable': false,
        'exactAlarmGranted': null,
        'batteryOptDisabled': null,
      });
      expect(calls, isEmpty);
    });
  });
}
