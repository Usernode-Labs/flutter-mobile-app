import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/notification_permission_status.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.onhomeroom.app/alarm');

  late List<String> calls;
  late Map<String, List<Object?>> responses;
  late PlatformAlarmService service;

  Future<void> setUpService() async {
    SharedPreferences.setMockInitialValues({});
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

  /// Delivers the person's answer to the POST_NOTIFICATIONS dialog the way
  /// native `onRequestPermissionsResult` does.
  Future<void> answerNotificationDialog({required bool granted}) {
    return binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(
        MethodCall('onPostNotificationsPermissionResult', {'granted': granted}),
      ),
      (_) {},
    );
  }

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('requestAlarmPermissions', () {
    test('android: asks for the missing exact alarm only, never notifications',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [false];
      responses['isBatteryOptimizationDisabled'] = [false];

      final granted = await service.requestAlarmPermissions();

      // One system surface per call: the exact-alarm settings page must not
      // be buried under the battery dialog. SV asks again for the battery
      // step once the user is back.
      expect(granted, isFalse);
      expect(calls, [
        'hasExactAlarmPermission',
        'requestExactAlarmPermission',
      ]);
    });

    test('android: exact alarm granted, battery pending -> true', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [false];

      final granted = await service.requestAlarmPermissions();

      expect(granted, isTrue);
      expect(calls, [
        'hasExactAlarmPermission',
        'isBatteryOptimizationDisabled',
        'requestBatteryOptimizationExemption',
      ]);
    });

    test('android: a request marks the next resume as a settings return',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [false];

      expect(service.consumeRecentSystemSurfaceLaunch(), isFalse);
      await service.requestAlarmPermissions();

      expect(service.consumeRecentSystemSurfaceLaunch(), isTrue);
      // Only the one resume that brings the user back is quiet.
      expect(service.consumeRecentSystemSurfaceLaunch(), isFalse);
    });

    test('android: nothing to ask leaves the next resume alone', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [true];

      await service.requestAlarmPermissions();

      expect(service.consumeRecentSystemSurfaceLaunch(), isFalse);
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
    test('iOS: delegates to requestNotificationPermission', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();
      responses['requestNotificationPermission'] = [true];

      final granted = await service.requestNotificationsPermission();

      expect(granted, isTrue);
      expect(calls, ['requestNotificationPermission']);
    });
  });

  group('android POST_NOTIFICATIONS waits for the answer', () {
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    testWidgets('an answer two seconds later is the answer', (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, true];
      responses['requestPostNotificationsPermission'] = [true];

      bool? granted;
      unawaited(
        service.requestNotificationsPermission().then((v) => granted = v),
      );

      // The old fixed 500 ms re-read answered by now, dialog still up.
      await tester.pump(const Duration(seconds: 2));
      expect(granted, isNull);
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
      ]);

      await answerNotificationDialog(granted: true);
      await tester.pump();

      expect(granted, isTrue);
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
        'hasPostNotificationsPermission',
      ]);
      expect(await NotificationPermissionRequestLog.requestedBefore(), isTrue);
    }, variant: android);

    testWidgets('a refusal resolves denied without waiting out the clock',
        (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, false];
      responses['requestPostNotificationsPermission'] = [true];

      bool? granted;
      unawaited(
        service.requestNotificationsPermission().then((v) => granted = v),
      );
      await tester.pump();
      // After two refusals Android shows no dialog and answers at once.
      await answerNotificationDialog(granted: false);
      await tester.pump();

      expect(granted, isFalse);
      expect(calls.last, 'hasPostNotificationsPermission');
      // Asked, so the settings snapshot reads `denied`, not `notDetermined`.
      expect(await NotificationPermissionRequestLog.requestedBefore(), isTrue);
    }, variant: android);

    testWidgets('no answer: reads the permission once the wait runs out',
        (tester) async {
      const timeout = PlatformAlarmService.postNotificationsAnswerTimeout;
      // The web bridge gives up on a permission request after 120 s.
      expect(timeout, lessThan(const Duration(seconds: 120)));
      await setUpService();
      // Allowed, but the answer never reached Dart.
      responses['hasPostNotificationsPermission'] = [false, true];
      responses['requestPostNotificationsPermission'] = [true];

      bool? granted;
      unawaited(
        service.requestNotificationsPermission().then((v) => granted = v),
      );

      await tester.pump(timeout - const Duration(seconds: 1));
      expect(granted, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(granted, isTrue);
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
        'hasPostNotificationsPermission',
      ]);

      // An answer that turns up after the wait gave up changes nothing.
      await answerNotificationDialog(granted: true);
      await tester.pump();
      expect(calls, hasLength(3));
    }, variant: android);

    testWidgets('already granted: no dialog and no wait', (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [true];

      bool? granted;
      unawaited(
        service.requestNotificationsPermission().then((v) => granted = v),
      );
      await tester.pump();

      expect(granted, isTrue);
      expect(calls, ['hasPostNotificationsPermission']);
      expect(service.consumeRecentSystemSurfaceLaunch(), isFalse);
    }, variant: android);

    testWidgets('no Activity: nothing shown or recorded, no wait for an answer',
        (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, false];
      responses['requestPostNotificationsPermission'] = [false];

      bool? granted;
      unawaited(
        service.requestNotificationsPermission().then((v) => granted = v),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(granted, isFalse);
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
        'hasPostNotificationsPermission',
      ]);
      expect(await NotificationPermissionRequestLog.requestedBefore(), isFalse);
    }, variant: android);

    testWidgets('a second ask while the dialog is up joins it', (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, true];
      responses['requestPostNotificationsPermission'] = [true];

      bool? first;
      bool? second;
      unawaited(
        service.requestNotificationsPermission().then((v) => first = v),
      );
      await tester.pump();
      unawaited(
        service.requestNotificationsPermission().then((v) => second = v),
      );
      await tester.pump(const Duration(seconds: 1));

      await answerNotificationDialog(granted: true);
      await tester.pump();

      expect((first, second), (true, true));
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
        'hasPostNotificationsPermission',
      ]);
    }, variant: android);

    testWidgets('requestPermissions opens exact alarms only after the answer',
        (tester) async {
      await setUpService();
      responses['hasPostNotificationsPermission'] = [false, true];
      responses['requestPostNotificationsPermission'] = [true];
      responses['hasExactAlarmPermission'] = [false];

      bool? granted;
      unawaited(service.requestPermissions().then((v) => granted = v));

      // One system surface at a time: nothing opens over the dialog.
      await tester.pump(const Duration(seconds: 2));
      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
      ]);

      await answerNotificationDialog(granted: true);
      await tester.pump();

      expect(calls, [
        'hasPostNotificationsPermission',
        'requestPostNotificationsPermission',
        'hasPostNotificationsPermission',
        'hasExactAlarmPermission',
        'requestExactAlarmPermission',
      ]);
      // Notifications allowed; the exact-alarm page is the next step.
      expect(granted, isFalse);
    }, variant: android);
  });

  group('notificationPermissionStatus', () {
    test('iOS reads the native three-state answer', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();
      responses['getNotificationAuthorizationStatus'] = [
        'notDetermined',
        'denied',
        'authorized',
      ];

      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.notDetermined,
      );
      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.denied,
      );
      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.authorized,
      );
      expect(calls, everyElement('getNotificationAuthorizationStatus'));
    });

    test('android 13+: undetermined until the app has asked', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      const off = {'enabled': false, 'runtimePermission': true};
      responses['getNotificationPermissionState'] = [off, off];
      responses['hasPostNotificationsPermission'] = [false, false];

      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.notDetermined,
      );
      expect(await service.requestNotificationsPermission(), isFalse);
      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.denied,
      );
    });

    test('android: enabled is authorized; switched off pre-13 is denied',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['getNotificationPermissionState'] = [
        {'enabled': true, 'runtimePermission': true},
        {'enabled': false, 'runtimePermission': false},
      ];

      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.authorized,
      );
      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.denied,
      );
    });

    test('a failing probe reads as notDetermined, never throws', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await setUpService();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        throw PlatformException(code: 'boom');
      });

      expect(
        await service.notificationPermissionStatus(),
        NotificationPermissionStatus.notDetermined,
      );
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

    test('propagates a native false (no Activity attached)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['openNotificationSettings'] = [false];

      expect(await service.openNotificationSettings(), isFalse);
    });
  });

  group('requestPermissions (legacy bundle)', () {
    test('android: keeps notifications → exact alarm → battery order',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      responses['hasPostNotificationsPermission'] = [true];
      responses['hasExactAlarmPermission'] = [true];
      responses['isBatteryOptimizationDisabled'] = [true];

      final granted = await service.requestPermissions();

      expect(granted, isTrue);
      expect(calls, [
        'hasPostNotificationsPermission',
        'hasExactAlarmPermission',
        'isBatteryOptimizationDisabled',
      ]);
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

    test('android: one probe failing does not mask the other', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await setUpService();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        calls.add(call.method);
        if (call.method == 'hasExactAlarmPermission') {
          throw PlatformException(code: 'boom');
        }
        if (call.method == 'isBatteryOptimizationDisabled') return true;
        return null;
      });

      final snapshot = await service.alarmPermissionsSnapshot();

      expect(snapshot, {
        'applicable': true,
        'exactAlarmGranted': false,
        'batteryOptDisabled': true,
      });
    });
  });

  group('application incarnation event fence', () {
    test('rejects a stale scheduled event before invoking Dart work', () async {
      await setUpService();
      service.setApplicationIncarnationForTesting('current');
      var callbackCalls = 0;
      service.setNativeEventCallback((_, __) async {
        callbackCalls += 1;
        return true;
      });

      expect(
        await service.dispatchNativeEventForTesting(
          'android_alarm_fired',
          const {'applicationIncarnation': 'old'},
        ),
        isFalse,
      );
      expect(callbackCalls, 0);

      expect(
        await service.dispatchNativeEventForTesting(
          'android_alarm_fired',
          const {'applicationIncarnation': 'current'},
        ),
        isTrue,
      );
      expect(callbackCalls, 1);
    });

    test('permission events remain unscoped and process restart rejects work',
        () async {
      await setUpService();
      service.setApplicationIncarnationForTesting('current');
      var callbackCalls = 0;
      service.setNativeEventCallback((_, __) async {
        callbackCalls += 1;
        return true;
      });

      expect(
        await service.dispatchNativeEventForTesting(
          'android_exact_alarm_permission_granted',
          const {},
        ),
        isTrue,
      );
      service.beginProcessRestart();
      expect(
        await service.dispatchNativeEventForTesting(
          'android_alarm_fired',
          const {'applicationIncarnation': 'current'},
        ),
        isFalse,
      );
      expect(callbackCalls, 1);
    });
  });

  test('permission changes reach every listener', () async {
    await setUpService();
    var first = 0;
    var second = 0;
    final a = service.permissionChanges.listen((_) => first++);
    final b = service.permissionChanges.listen((_) => second++);

    service.notifyPermissionsMayHaveChanged();

    expect((first, second), (1, 1));
    await a.cancel();
    await b.cancel();
  });
}
