import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Producer work uses ordinary completion plus the process runtime/scheduler
/// owners. It does not grow a second per-effect lifecycle protocol in Dart.
void main() {
  late String foregroundController;
  late String alarmAudit;

  setUpAll(() async {
    foregroundController = await File(
      'lib/core/services/android_foreground_task_controller.dart',
    ).readAsString();
    alarmAudit = await File(
      'lib/core/services/block_production_alarm_audit_service.dart',
    ).readAsString();
  });

  test('producer paths contain no Dart generation lease or settle handshake',
      () {
    final sources = '$foregroundController\n$alarmAudit';
    for (final forbidden in [
      '_monitoringGeneration',
      '_watchdogLifecycleGeneration',
      'retireMonitoringSession',
      '_superseded(',
      'Future<void> settle()',
    ]) {
      expect(sources, isNot(contains(forbidden)));
    }
  });

  test('foreground teardown waits for the one active poll', () {
    expect(foregroundController, contains('await _drainActivePoll();'));
  });

  test('an accepted alarm schedule is not re-authorized after awaits', () {
    final scheduleStart = foregroundController.indexOf(
      'Future<ForegroundResumeAlarmScheduleResult> scheduleResumeAlarm({',
    );
    final schedule = foregroundController.substring(
      scheduleStart,
      foregroundController.indexOf(
        'Future<int?> resolveEpochEndTimeMs(',
        scheduleStart,
      ),
    );
    expect(schedule, isNot(contains('_terminalResetRequested')));
  });
}
