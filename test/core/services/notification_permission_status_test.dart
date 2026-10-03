import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/services/notification_permission_status.dart';

void main() {
  test('the wire values are the three names SV reads', () {
    expect(
      NotificationPermissionStatus.values.map((s) => s.name),
      ['notDetermined', 'denied', 'authorized'],
    );
  });

  test('fromWire reads platform answers; anything else is notDetermined', () {
    expect(
      NotificationPermissionStatus.fromWire('authorized'),
      NotificationPermissionStatus.authorized,
    );
    expect(
      NotificationPermissionStatus.fromWire('denied'),
      NotificationPermissionStatus.denied,
    );
    for (final raw in <Object?>[null, '', 'provisional', 'Authorized', 3]) {
      expect(
        NotificationPermissionStatus.fromWire(raw),
        NotificationPermissionStatus.notDetermined,
        reason: '$raw',
      );
    }
  });

  group('androidNotificationPermissionStatus', () {
    NotificationPermissionStatus status({
      required bool enabled,
      bool runtimePermission = true,
      bool requestedBefore = false,
    }) =>
        androidNotificationPermissionStatus(
          enabled: enabled,
          runtimePermission: runtimePermission,
          requestedBefore: requestedBefore,
        );

    test('enabled is authorized whatever else is true', () {
      expect(
        status(enabled: true),
        NotificationPermissionStatus.authorized,
      );
      expect(
        status(enabled: true, runtimePermission: false, requestedBefore: true),
        NotificationPermissionStatus.authorized,
      );
    });

    test('13+: never asked is notDetermined, asked before is denied', () {
      expect(
        status(enabled: false),
        NotificationPermissionStatus.notDetermined,
      );
      expect(
        status(enabled: false, requestedBefore: true),
        NotificationPermissionStatus.denied,
      );
    });

    test('before 13 there is no dialog: off means switched off', () {
      expect(
        status(enabled: false, runtimePermission: false),
        NotificationPermissionStatus.denied,
      );
    });
  });

  group('NotificationPermissionRequestLog', () {
    test('nothing recorded on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await NotificationPermissionRequestLog.requestedBefore(), isFalse);
    });

    test('markRequested is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      await NotificationPermissionRequestLog.markRequested();
      expect(await NotificationPermissionRequestLog.requestedBefore(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool(NotificationPermissionRequestLog.requestedKey),
        isTrue,
      );
    });

    test('an install the retired startup prompt asked counts as asked',
        () async {
      SharedPreferences.setMockInitialValues({
        NotificationPermissionRequestLog.legacyStartupPromptKey: true,
      });
      expect(await NotificationPermissionRequestLog.requestedBefore(), isTrue);
    });
  });
}
