import 'dart:io';

import 'package:crypto_mobile_app/features/dapps/android_webview_microphone.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidWebViewMicrophone.channelName);
  const subject = AndroidWebViewMicrophone();
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<bool> configure() => subject.configureForWebView(
        7,
        trustedOrigin: 'https://app.onhomeroom.com/',
      );

  test('configures only the named WebView and deployment origin', () async {
    expect(await configure(), isTrue);
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {
      'webViewIdentifier': 7,
      'trustedOrigin': 'https://app.onhomeroom.com/',
    });
  });

  test('leaves iOS permission handling untouched', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await configure(), isFalse);
    expect(calls, isEmpty);
  });

  test('a missing native adapter fails closed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await configure(), isFalse);
  });

  test('native failure fails closed without blocking the page', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await configure(), isFalse);
  });

  test('Android declares audio recording without requiring microphone hardware',
      () async {
    final manifest =
        await File('android/app/src/main/AndroidManifest.xml').readAsString();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.permission.MODIFY_AUDIO_SETTINGS'));
    expect(
      manifest,
      contains(
        '<uses-feature android:name="android.hardware.microphone" '
        'android:required="false" />',
      ),
    );
  });
}
