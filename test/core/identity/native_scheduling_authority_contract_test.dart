import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const nativeRoot =
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm';

  test('the exact runtime owner replaces the incarnation compatibility fence',
      () {
    expect(File('$nativeRoot/RuntimeOwner.kt').existsSync(), isTrue);
    expect(
      File('$nativeRoot/ApplicationIncarnationStore.kt').existsSync(),
      isFalse,
    );

    final production = <File>[
      ...Directory(nativeRoot)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.kt')),
      File('android/app/src/main/kotlin/com/example/mobile_app/MainActivity.kt'),
      File('lib/core/services/platform_alarm_service.dart'),
      File('lib/core/identity/session_controller.dart'),
    ];
    for (final file in production) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('ApplicationIncarnation')),
        reason: '${file.path} retains the removed store',
      );
      expect(
        source,
        isNot(contains('applicationIncarnation')),
        reason: '${file.path} retains the removed token',
      );
    }
  });

  test('every privileged Android scheduling sink carries RuntimeOwner', () {
    for (final name in [
      'AlarmScheduler.kt',
      'AlarmWatchdogScheduler.kt',
      'AlarmWatchdogWorker.kt',
      'ForegroundServiceManager.kt',
      'NativeWakeLockManager.kt',
      'SlotMonitoringService.kt',
    ]) {
      final source = File('$nativeRoot/$name').readAsStringSync();
      expect(source, contains('RuntimeOwner'), reason: name);
    }

    final authority =
        File('$nativeRoot/NativeSchedulingAuthority.kt').readAsStringSync();
    expect(authority, contains('runIfAdmitted'));
    expect(authority, contains('runIfOwned'));
    expect(authority, isNot(contains('runIfCurrent')));
  });

  test('iOS has no production slot scheduler or compatibility handler', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final dart = File('lib/core/services/platform_alarm_service.dart')
        .readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(File('ios/Runner/BGTaskSchedulerManager.swift').existsSync(), isFalse);
    for (final source in [delegate, dart, project, plist]) {
      expect(source, isNot(contains('scheduleIOSBGTask')));
      expect(source, isNot(contains('BGTaskSchedulerManager')));
      expect(source, isNot(contains('slotmonitoring')));
    }
    expect(delegate, isNot(contains('registerBGTasks')));
    expect(delegate, isNot(contains('blockProductionSlot')));
    expect(delegate, contains('requestNotificationPermission'));
    expect(delegate, contains('usernode_social'));
  });
}
