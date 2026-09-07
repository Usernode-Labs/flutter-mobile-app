import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account requests validate the session without producer scheduling', () {
    final android = File(
      'android/app/src/main/kotlin/com/usernode_labs/usernode/session/'
      'InteractiveNativeSessionChannel.kt',
    ).readAsStringSync();
    final androidGate = android.substring(
      android.indexOf('private fun managedArguments('),
      android.indexOf('private fun runWorker('),
    );
    expect(androidGate, contains('requireProcessTransportClaim(arguments)'));
    expect(
        androidGate,
        contains(
            'NativeSessionRust.nativeIsManagedSessionCurrentV1(revision)'));
    expect(androidGate, isNot(contains('NativeProducerWakeCoordinator')));

    final ios =
        File('ios/Runner/NativeSessionPlatform.swift').readAsStringSync();
    final iosGate = ios.substring(
      ios.indexOf('private func managed('),
      ios.indexOf('private func exactArguments('),
    );
    expect(iosGate, contains('authorized(call, keys: keys)'));
    expect(iosGate,
        contains('IOSNativeSessionRust.isManagedSessionCurrent(revision)'));
    expect(iosGate, isNot(contains('vault.isReadyRevision')));
  });
}
