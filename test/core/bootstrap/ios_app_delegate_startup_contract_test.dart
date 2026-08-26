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
}
