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
}
