import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android loads the shipped Rust library and uses the support path', () {
    final source = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'SessionAuthorityNative.kt',
    ).readAsStringSync();

    expect(source, contains('System.loadLibrary("usernode")'));
    expect(source, contains('context.filesDir'));
    expect(source, contains('"session-authority"'));
    expect(source, contains('external fun readAdmissionJson'));
    expect(source, contains('external fun admitsBackgroundRuntime'));
  });

  test('iOS calls the same Rust-owned C bridge from Application Support', () {
    final header =
        File('ios/Runner/Runner-Bridging-Header.h').readAsStringSync();
    final source =
        File('ios/Runner/SessionAuthorityNative.swift').readAsStringSync();
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(header, contains('usernode_session_authority_admission_json'));
    expect(header, contains('usernode_session_authority_string_free'));
    expect(source, contains('.applicationSupportDirectory'));
    expect(source, contains('"session-authority"'));
    expect(source, contains('usernode_session_authority_admission_json'));
    expect(source, contains('usernode_session_authority_string_free'));
    expect(
      RegExp('SessionAuthorityNative\\.swift in Sources')
          .allMatches(project)
          .length,
      2,
    );
  });

  test('legacy native cleanup is targeted and never wipes app preferences', () {
    final android = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/alarm/'
      'AlarmMethodChannelHandler.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    final androidCleanup = _functionBody(
      android,
      'private fun clearLegacySessionAuthority()',
      'private fun clearNativeResetState()',
    );
    expect(android, contains('"clearLegacySessionAuthority"'));
    expect(androidCleanup, contains('alarm_prefs'));
    expect(androidCleanup, contains('alarm_watchdog_prefs'));
    expect(androidCleanup, contains('applicationIncarnationStore.clear()'));
    expect(androidCleanup, isNot(contains('background_task_stats')));

    final iosCleanup = _functionBody(
      ios,
      'private func clearLegacySessionAuthority()',
      'private func clearNativeResetState()',
    );
    expect(ios, contains('case "clearLegacySessionAuthority"'));
    expect(iosCleanup, contains('cancelAllBGTasks()'));
    expect(
      iosCleanup,
      contains('ApplicationIncarnationStore.shared.clearForMigration()'),
    );
    expect(iosCleanup, isNot(contains('dictionaryRepresentation')));
    expect(iosCleanup, isNot(contains('removePersistentDomain')));

    final migrationClear = _functionBody(
      ios,
      'func clearForMigration()',
      'func rotate()',
    );
    expect(migrationClear, isNot(contains('terminalResetRequested = true')));
  });
}

String _functionBody(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex),
      reason: 'missing $end after $start');
  return source.substring(startIndex, endIndex);
}
