import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String appDelegate;

  setUpAll(() async {
    appDelegate = await File('ios/Runner/AppDelegate.swift').readAsString();
  });

  test('iOS plugins and channels wait for the implicit Flutter engine', () {
    expect(appDelegate, contains('FlutterImplicitEngineDelegate'));
    expect(
      appDelegate,
      contains(
        'func didInitializeImplicitFlutterEngine('
        '_ engineBridge: FlutterImplicitEngineBridge',
      ),
    );
    expect(
      appDelegate,
      contains(
        'GeneratedPluginRegistrant.register('
        'with: engineBridge.pluginRegistry)',
      ),
    );
    expect(
      appDelegate,
      contains('engineBridge.applicationRegistrar.messenger()'),
    );
    expect(
      'GeneratedPluginRegistrant.register'.allMatches(appDelegate),
      hasLength(1),
    );
    expect(
      appDelegate,
      isNot(contains('GeneratedPluginRegistrant.register(with: self)')),
    );
    expect(appDelegate, isNot(contains('window?.rootViewController')));
  });

  // Built with the iOS 27 SDK, an app with no scene manifest stops at launch
  // (UIKit's _UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption,
  // seen on the iOS 27.1 simulator), on every iPhone.
  test('iOS runs the UIScene lifecycle through FlutterSceneDelegate', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();
    expect(plist, contains('<key>UIApplicationSceneManifest</key>'));
    expect(plist, contains('<string>FlutterSceneDelegate</string>'));
    expect(
      plist,
      contains(
        '<key>UIApplicationSupportsMultipleScenes</key>\n\t\t<false/>',
      ),
    );
    // Under scenes the app delegate's own window is nil.
    expect(appDelegate, isNot(contains('self.window')));
    expect(appDelegate, contains('connectedScenes'));
  });

  // On iPhone Duo the key kept the app at a phone's size on the inner
  // display; the iOS 27 SDK no longer lets it opt out of resizing anyway.
  test('iOS does not ask to be full screen', () async {
    final plist = await File('ios/Runner/Info.plist').readAsString();
    expect(plist, isNot(contains('<key>UIRequiresFullScreen</key>')));
  });
}
