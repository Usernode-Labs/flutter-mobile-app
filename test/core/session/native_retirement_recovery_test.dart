import 'dart:io';
import 'dart:typed_data';

import 'package:crypto_mobile_app/main.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() => RustLib.initMock(api: _HealthyRustLifecycle()));

  test('a session the server ended no longer blocks the next sign-in',
      () async {
    expect(await runNativeRetirementRecoverySelfCheck(), [
      'launch-absence-signed-out',
      'launch-absence-sign-in-established',
      'restore-absence-signed-out',
      'restore-absence-sign-in-established',
      'signed-in-absence-signed-out',
      'signed-in-absence-sign-in-established',
      'native-retirement-latched',
      'failed-retirement-latched',
    ]);
  });

  test('interactive iOS wakes report absence instead of retiring in Rust', () {
    final platform =
        File('ios/Runner/NativeSessionPlatform.swift').readAsStringSync();
    final run = platform.substring(
      platform.indexOf('private func runLocked('),
      platform.indexOf('private func apply('),
    );
    final handOff = run.indexOf(
      'if case .absent = credential, source == .foregroundResume {',
    );
    expect(handOff, greaterThanOrEqualTo(0));
    expect(
      run.indexOf('outcome: "credentialAbsent"', handOff),
      greaterThan(handOff),
    );
    // Background wakes have no Flutter owner and still resolve in Rust.
    expect(
      run.indexOf('resolveProducerCredentialAbsent(&request)'),
      greaterThan(handOff),
    );
  });
}

/// Rust as it behaves for a healthy process root: logout commits LoggedOut
/// and establishment commits the requested attempt.
final class _HealthyRustLifecycle implements RustLibApi {
  var _revision = 1;

  @override
  Future<NativeLogoutResult> crateMobileApiLogoutNativeSession({
    required ProcessRootClient root,
    required SessionNativeClient session,
  }) async =>
      NativeLogoutResult(
        nativeRevision: BigInt.from(++_revision),
        credentialRetirement: NativeCredentialRetirement(
          credentialReference: 'self-check-credential',
          credentialGeneration: BigInt.one,
          vaultCommitment: Uint8List(32),
        ),
      );

  @override
  Future<NativeEstablishResult> crateMobileApiEstablishNativeSession({
    required ProcessRootClient root,
    required NativeEstablishRequest request,
  }) async =>
      NativeEstablishResult(
        protocol: 2,
        attemptId: request.attemptId,
        nativeRevision: BigInt.from(++_revision),
        identity: const NativeIdentity(participantId: '2'),
        runtimeStatus: const NativeRuntimeStatus.notStarted(),
        receiptStatus: NativeReceiptStatus.committedReady,
      );

  @override
  SessionNativeClient crateMobileApiCurrentNativeSession({
    required ProcessRootClient root,
    required BigInt expectedRevision,
  }) =>
      _Session();

  @override
  Future<NativeSleepySnapshot> crateMobileApiNativeSleepy({
    required ProcessRootClient root,
    required SessionNativeClient session,
    required bool enabled,
  }) async =>
      NativeSleepySnapshot(
        enabled: enabled,
        decision: const NativeSleepyDecision.disabled(),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Session implements SessionNativeClient {
  bool _disposed = false;

  @override
  void dispose() => _disposed = true;

  @override
  bool get isDisposed => _disposed;
}
