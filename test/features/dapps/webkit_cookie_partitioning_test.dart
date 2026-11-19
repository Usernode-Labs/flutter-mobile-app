import 'dart:io';

import 'package:crypto_mobile_app/features/dapps/webkit_cookie_partitioning.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(WebKitCookiePartitioning.channelName);
  const subject = WebKitCookiePartitioning();
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

    test('asks native to refresh the setting for that one web view', () async {
      answer((_) async => true);

      expect(await subject.refreshForWebView(7), isTrue);
      expect(calls.single.method, 'refreshCookiePartitioning');
      expect(calls.single.arguments, {'webViewIdentifier': 7});
    });

    test('reports a web view native could not find', () async {
      answer((_) async => false);

      expect(await subject.refreshForWebView(7), isFalse);
    });

    test('a native error changes nothing instead of throwing', () async {
      answer((_) async => throw PlatformException(code: 'invalid_args'));

      expect(await subject.refreshForWebView(7), isFalse);
    });

    test('a missing native handler changes nothing', () async {
      expect(await subject.refreshForWebView(7), isFalse);
    });
  });

  test('Android WebView is not affected, so nothing is sent', () async {
    runOn(TargetPlatform.android);
    answer((_) async => true);

    expect(await subject.refreshForWebView(7), isFalse);
    expect(calls, isEmpty);
  });

  group('iOS native contract', () {
    late String swift;
    late String appDelegate;
    late String project;
    late String screen;

    setUpAll(() async {
      swift = await File(
        'ios/Runner/WebKitCookiePartitioning.swift',
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
          'static let channelName = "${WebKitCookiePartitioning.channelName}"',
        ),
      );
      expect(swift, contains('call.method == "refreshCookiePartitioning"'));
      expect(swift, contains('args["webViewIdentifier"]'));
    });

    test('the app registers the channel and every page start asks for it', () {
      expect(appDelegate, contains('WebKitCookiePartitioning.makeChannel('));
      final onPageStarted = RegExp(
        r'onPageStarted: \(_\) \{[\s\S]*?\n          \},',
      ).firstMatch(screen);
      expect(onPageStarted, isNotNull);
      expect(
        onPageStarted!.group(0),
        contains('const WebKitCookiePartitioning().refreshFor(_controller)'),
      );
      expect(
        RegExp(
          r'/\* WebKitCookiePartitioning\.swift in Sources \*/',
        ).allMatches(project),
        hasLength(2),
        reason: 'the Runner target must compile the Swift file',
      );
    });

    test('the throwaway web view shares the platform one and loads nothing',
        () {
      // Same data store: the setting is per data store. Same App-Bound
      // Domains choice. No load, no bridge, and the platform web view's own
      // configuration is never written to.
      expect(
        swift,
        contains(
          'configuration.websiteDataStore = '
          'webView.configuration.websiteDataStore',
        ),
      );
      expect(
        swift,
        contains(
          'configuration.limitsNavigationsToAppBoundDomains =\n'
          '      webView.configuration.limitsNavigationsToAppBoundDomains',
        ),
      );
      expect(swift, isNot(contains('.load(')));
      expect(swift, isNot(contains('addScriptMessageHandler')));
      expect(swift, isNot(contains('webView.configuration.preferences.')));
    });
  });
}
