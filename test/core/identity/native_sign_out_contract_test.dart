import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scoped sign-out boundary is half native, and no Dart test can reach the
/// WebView store, the incarnation token or the notification tray. These assert
/// the contract the Dart side depends on, so a regression there is visible in
/// CI rather than only on a device.
void main() {
  late String androidHandler;
  late String androidIncarnation;
  late String androidGradle;
  late String iosAppDelegate;

  setUpAll(() async {
    androidHandler = await File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'AlarmMethodChannelHandler.kt',
    ).readAsString();
    androidIncarnation = await File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'ApplicationIncarnationStore.kt',
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

  test('the native generation can be retired without latching the app shut',
      () {
    // The reversible twin of `invalidate()`: sign-out retires the token every
    // durable alarm/watchdog/headless event captured, while this surviving
    // process keeps scheduling under the successor token.
    final rotate = androidIncarnation.substring(
      androidIncarnation.indexOf('fun rotate(): String?'),
      androidIncarnation.indexOf('fun invalidate(): Boolean'),
    );
    expect(rotate, contains('UUID.randomUUID().toString()'));
    expect(rotate, isNot(contains('terminalResetRequested = true')));
    expect(rotate, contains('if (terminalResetRequested) return@synchronized'));
    expect(androidHandler, contains('"rotateApplicationIncarnation" ->'));

    expect(iosAppDelegate, contains('func rotate() -> String?'));
    expect(iosAppDelegate, contains('case "rotateApplicationIncarnation":'));
    final iosRotate = iosAppDelegate.substring(
      iosAppDelegate.indexOf('func rotate() -> String?'),
      iosAppDelegate.indexOf('@main'),
    );
    expect(iosRotate, isNot(contains('terminalResetRequested = true')));
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
