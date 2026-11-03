import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto_mobile_app/main.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rust = _HealthyRustLifecycle();
  setUpAll(() => RustLib.initMock(api: rust));

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

  for (final submitTransaction in [false, true]) {
    test(
        'logout interrupts ${submitTransaction ? 'transaction' : 'explicit'} preparation',
        () async {
      rust.parametersReady = false;
      rust.preparationStarted = Completer<void>();
      rust.preparationRelease = Completer<void>();
      rust.establishments = 0;
      try {
        final checking = runNativePreparationRetirementSelfCheck(
            submitTransaction: submitTransaction);
        await rust.preparationStarted!.future;
        // The selfcheck retires the owner on the next event turn while Rust waits.
        await Future<void>.delayed(Duration.zero);
        rust.preparationRelease!.complete();
        expect(await checking, [
          'preparation-does-not-block-retirement',
          'preparation-handoff-not-redeemed',
        ]);
        expect(rust.establishments, 0);
      } finally {
        if (!rust.preparationRelease!.isCompleted) {
          rust.preparationRelease!.complete();
        }
        rust.parametersReady = true;
        rust.preparationStarted = null;
        rust.preparationRelease = null;
      }
    });
  }

  test('sign-in establishes without downloading proving parameters', () async {
    rust.parametersReady = false;
    rust.preparationCalls = 0;
    rust.establishments = 0;
    try {
      expect(await runNativeUnpreparedEstablishmentSelfCheck(), isTrue);
      expect(rust.establishments, 1);
      expect(rust.preparationCalls, 0);
    } finally {
      rust.parametersReady = true;
    }
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
  var parametersReady = true;
  var preparationCalls = 0;
  var establishments = 0;
  Completer<void>? preparationStarted;
  Completer<void>? preparationRelease;

  @override
  NativeProvingParametersStatus crateMobileApiNativeProvingParametersStatus({
    required ProcessRootClient root,
  }) =>
      NativeProvingParametersStatus(
        ready: parametersReady,
        completedBytes: parametersReady ? BigInt.from(10) : BigInt.zero,
        totalBytes: BigInt.from(10),
      );

  @override
  Future<void> crateMobileApiNativePrepareProvingParameters({
    required ProcessRootClient root,
  }) async {
    preparationCalls++;
    preparationStarted?.complete();
    final release = preparationRelease;
    if (release != null) await release.future;
    parametersReady = true;
  }

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
  }) async {
    establishments++;
    return NativeEstablishResult(
      protocol: 2,
      attemptId: request.attemptId,
      nativeRevision: BigInt.from(++_revision),
      identity: const NativeIdentity(participantId: '2'),
      runtimeStatus: const NativeRuntimeStatus.notStarted(),
      receiptStatus: NativeReceiptStatus.committedReady,
    );
  }

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
