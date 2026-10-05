import 'dart:io';

import 'package:crypto_mobile_app/features/dapps/webview_form_accessory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(WebViewFormAccessory.channelName);
  const subject = WebViewFormAccessory();
  final calls = <MethodCall>[];

  void answer(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  void runOn(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  tearDown(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('on iOS', () {
    setUp(() => runOn(TargetPlatform.iOS));

    test('asks native to hide the bar for that one web view', () async {
      answer((_) async => true);

      expect(await subject.hideForWebView(7), isTrue);
      expect(calls.single.method, 'hideFormAccessoryBar');
      expect(calls.single.arguments, {'webViewIdentifier': 7});
    });

    test('reports a web view native could not change', () async {
      answer((_) async => false);

      expect(await subject.hideForWebView(7), isFalse);
    });

    test('a native error leaves the bar instead of throwing', () async {
      answer((_) async => throw PlatformException(code: 'invalid_args'));

      expect(await subject.hideForWebView(7), isFalse);
    });

    test('a missing native handler leaves the bar', () async {
      expect(await subject.hideForWebView(7), isFalse);
    });
  });

  test('Android WebView has no such bar, so nothing is sent', () async {
    runOn(TargetPlatform.android);
    answer((_) async => true);

    expect(await subject.hideForWebView(7), isFalse);
    expect(calls, isEmpty);
  });

  group('iOS native contract', () {
    late String swift;
    late String appDelegate;
    late String project;
    late String screen;

    setUpAll(() async {
      swift = await File(
        'ios/Runner/WebViewFormAccessory.swift',
      ).readAsString();
      appDelegate = await File('ios/Runner/AppDelegate.swift').readAsString();
      project = await File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsString();
      screen = await File(
        'lib/features/dapps/dapp_webview_screen.dart',
      ).readAsString();
    });

    test('Swift answers the channel and method Dart calls', () {
      expect(
        swift,
        contains(
          'static let channelName = "${WebViewFormAccessory.channelName}"',
        ),
      );
      expect(swift, contains('call.method == "hideFormAccessoryBar"'));
      expect(swift, contains('args["webViewIdentifier"]'));
    });

    test('the app registers the channel and the web view asks for it', () {
      expect(appDelegate, contains('WebViewFormAccessory.makeChannel('));
      expect(
        appDelegate,
        contains('pluginRegistry: engineBridge.pluginRegistry'),
      );
      expect(
        screen,
        contains('const WebViewFormAccessory().hideFor(_controller)'),
      );
      expect(
        RegExp(
          r'/\* WebViewFormAccessory\.swift in Sources \*/',
        ).allMatches(project),
        hasLength(2),
        reason: 'the Runner target must compile the Swift file',
      );
    });

    test('only the platform web view loses the bar', () {
      // The plugin's supported lookup, then a class swap on that one content
      // view. Swizzling WKContentView itself would strip the bar from every
      // WKWebView in the process, including ones SDKs create.
      expect(swift, contains('FWFWebViewFlutterWKWebViewExternalAPI.webView('));
      expect(swift, contains('object_setClass(contentView, subclass)'));
      expect(swift, isNot(contains('method_setImplementation')));
      expect(swift, isNot(contains('method_exchangeImplementations')));
      expect(swift, isNot(contains('class_replaceMethod')));
    });
  });
}
