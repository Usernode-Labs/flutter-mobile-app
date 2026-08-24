import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scoped sign-out boundary is half native, and no Dart test can reach the
/// WebView store or notification tray. These assert the contract the Dart side
/// depends on, so a regression there is visible in CI rather than on a device.
void main() {
  late String androidHandler;
  late String androidGradle;
  late String iosAppDelegate;

  setUpAll(() async {
    androidHandler = await File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'AlarmMethodChannelHandler.kt',
    ).readAsString();
    androidGradle = await File('android/app/build.gradle').readAsString();
    iosAppDelegate = await File('ios/Runner/AppDelegate.swift').readAsString();
  });

  test('Android WebView deletion is comprehensive and awaited', () {
    // Framework `WebStorage.deleteAllData()` has no completion callback and
    // guarantees neither the network cache nor the service workers this app
    // enables for the SV shell, so it cannot back a security boundary.
    expect(androidGradle, contains('androidx.webkit:webkit:'));
    expect(androidHandler, contains('import androidx.webkit.WebStorageCompat'));
    expect(androidHandler, contains('import androidx.webkit.WebViewFeature'));

    final clear = androidHandler.substring(
      androidHandler.indexOf(
        'private fun clearWebSessionData(result: MethodChannel.Result)',
      ),
      androidHandler.indexOf('private fun clearSessionNotifications()'),
    );
    expect(
      clear,
      contains(
        'WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)',
      ),
    );
    expect(clear, contains('WebStorageCompat.deleteBrowsingData('));
    // Unsupported reports failure rather than a partial wipe; the Dart side
    // escalates to the terminal reset, whose data wipe does cover it.
    expect(clear, contains('result.success(false)'));
    expect(clear, isNot(contains('WebStorage.getInstance().deleteAllData()')));
  });

  test('foreground stop has one caller-independent path', () {
    final manager = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'ForegroundServiceManager.kt',
    ).readAsStringSync();
    expect(manager, contains('fun stopForegroundService('));
    expect(manager, isNot(contains('destroyBackgroundEngine')));
    expect(androidHandler, isNot(contains('destroyBackgroundEngine')));
  });

  test('the retired session leaves nothing on the tray or lock screen', () {
    expect(androidHandler, contains('"clearSessionNotifications" ->'));
    expect(
      androidHandler,
      contains('private fun clearSessionNotifications(): Boolean'),
    );

    expect(iosAppDelegate, contains('case "clearSessionNotifications":'));
    final iosClear = iosAppDelegate.substring(
      iosAppDelegate.indexOf(
        'private func clearSessionNotifications(result: @escaping FlutterResult)',
      ),
      iosAppDelegate.indexOf(
        'private func clearWebSessionData(result: @escaping FlutterResult)',
      ),
    );
    expect(iosClear, contains('removeAllPendingNotificationRequests()'));
    expect(iosClear, contains('removeAllDeliveredNotifications()'));
  });
}
