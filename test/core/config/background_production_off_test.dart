import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS asks for no background modes or background tasks', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('UIBackgroundModes')));
    expect(plist, isNot(contains('BGTaskSchedulerPermittedIdentifiers')));
  });

  test('iOS registers no background task at launch', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, isNot(contains('bgTaskScheduler.registerBGTasks()')));
  });

  test('Android declares no background service or alarm receiver', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('SlotMonitoringService')));
    expect(manifest, isNot(contains('AlarmReceiver')));
    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(manifest, isNot(contains('REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')));
    expect(manifest, isNot(contains('FOREGROUND_SERVICE_DATA_SYNC')));
  });
}
