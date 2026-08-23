import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String incarnation;
  late String scheduler;
  late String watchdog;
  late String foreground;
  late String wakelock;
  late String handler;
  late String dartService;

  setUpAll(() {
    const nativeRoot =
        'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm';
    incarnation =
        File('$nativeRoot/ApplicationIncarnationStore.kt').readAsStringSync();
    scheduler = File('$nativeRoot/AlarmScheduler.kt').readAsStringSync();
    watchdog = File('$nativeRoot/AlarmWatchdogScheduler.kt').readAsStringSync();
    foreground =
        File('$nativeRoot/ForegroundServiceManager.kt').readAsStringSync();
    wakelock = File('$nativeRoot/NativeWakeLockManager.kt').readAsStringSync();
    handler =
        File('$nativeRoot/AlarmMethodChannelHandler.kt').readAsStringSync();
    dartService = File('lib/core/services/platform_alarm_service.dart')
        .readAsStringSync();
  });

  test('alarm installation and incarnation rotation share one authority', () {
    expect(
      File(
        'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
        'NativeSchedulingAuthority.kt',
      ).existsSync(),
      isTrue,
    );
    expect(incarnation, contains('NativeSchedulingAuthority.process'));
    expect(incarnation, isNot(contains('private val lock = Any()')));

    final schedule = _between(
      scheduler,
      'fun scheduleExactAlarm(',
      'fun cancelAlarm(',
    );
    expect(
        schedule, contains('NativeSchedulingAuthority.process.runIfCurrent'));
    expect(schedule.indexOf('runIfCurrent'),
        lessThan(schedule.indexOf('setExact')));
    expect(schedule.indexOf('setExact'),
        lessThan(schedule.indexOf('recordScheduled')));
    expect(
      schedule.indexOf('recordScheduled'),
      lessThan(schedule.indexOf('showScheduledNotification')),
    );
  });

  test('all native scheduling mutations use the shared authority', () {
    for (final source in [scheduler, watchdog, foreground, wakelock]) {
      expect(source, contains('NativeSchedulingAuthority.process'));
    }
    expect(watchdog, contains('runIfCurrent'));
    expect(foreground, contains('runIfCurrent'));
    expect(wakelock, contains('runIfCurrent'));
  });

  test('Dart cancellation commands carry an exact captured incarnation', () {
    for (final method in [
      'cancelAlarm',
      'cancelAllAlarms',
      'cancelAlarmWatchdog',
      'stopForegroundService',
      'stopPersistentForegroundService',
      'releaseWakelock',
    ]) {
      final nativeCase = _methodCase(handler, method);
      expect(
        nativeCase,
        contains('currentIncarnationFromCall(call)'),
        reason: '$method must validate the captured incarnation natively',
      );

      final dartMethod = _dartMethod(dartService, method);
      expect(
        dartMethod,
        contains('applicationIncarnationKey: incarnation'),
        reason: '$method must send the incarnation captured before handoff',
      );
    }
  });
}

String _methodCase(String source, String method) {
  final start = source.indexOf('"$method" ->');
  expect(start, greaterThanOrEqualTo(0), reason: 'missing native $method');
  final end = source.indexOf('\n            "', start + method.length + 6);
  expect(end, greaterThan(start), reason: 'missing case after $method');
  return source.substring(start, end);
}

String _dartMethod(String source, String method) {
  final match =
      RegExp('Future<bool> $method(?:<[^>]+>)?\\(').firstMatch(source);
  expect(match, isNotNull, reason: 'missing Dart $method');
  final nextMethod = source.indexOf('\n  Future<', match!.end);
  expect(nextMethod, greaterThan(match.start),
      reason: 'missing method after $method');
  return source.substring(match.start, nextMethod);
}

String _between(String source, String startText, String endText) {
  final start = source.indexOf(startText);
  final end = source.indexOf(endText, start + startText.length);
  expect(start, greaterThanOrEqualTo(0), reason: 'missing $startText');
  expect(end, greaterThan(start), reason: 'missing $endText after $startText');
  return source.substring(start, end);
}
