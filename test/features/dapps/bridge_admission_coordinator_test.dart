import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/features/dapps/bridge_admission_coordinator.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:crypto_mobile_app/features/dapps/session_bound_auth_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trustedUrl = 'https://social-vibecoding.usernodelabs.org/';

  test('missing and invalid capabilities settle in the probed realm', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final secrets = _SecretSequence();
    final policy = _policy(frame, secrets: secrets);
    final coordinator = _coordinator(frame, policy: policy);

    for (final capability in <Object?>[null, '', 'guessed']) {
      final decision = await coordinator.admit(
        'getSettingsState',
        {'privilegedCapability': capability},
      );
      expect(decision.dispatch, isFalse);
      expect(decision.lease, isNotNull);
      expect(decision.error, contains('requires a trusted'));
      expect(
        await coordinator.runInRequestContext(
          admission: decision,
          body: () async => PrivilegedBridgeRequestContext.currentLease,
        ),
        same(decision.lease),
      );
    }
  });

  test('handoff closes before a later wallet admission can overtake it',
      () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final secrets = _SecretSequence();
    final policy = _policy(frame, secrets: secrets);
    final gate = SessionHandoffGate();
    final coordinator = _coordinator(frame, policy: policy, gate: gate);
    final lease = await policy.bootstrapLease();

    final handoff = coordinator.admit(
      'beginSessionHandoff',
      {'privilegedCapability': lease?.capability},
    );
    final wallet = coordinator.admit('getWalletState', const {});
    final handoffDecision = await handoff;
    final walletDecision = await wallet;
    expect(handoffDecision.value, const {'blocked': true});
    expect(walletDecision.dispatch, isFalse);
    expect(walletDecision.error, contains('identity transition'));
    expect(gate.isWalletBlocked, isTrue);
  });

  test('page start invalidates an in-flight readiness admission', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final secrets = _SecretSequence();
    final policy = _policy(frame, secrets: secrets);
    PrivilegedBridgeLease? ready;
    final coordinator = _coordinator(
      frame,
      policy: policy,
      onReady: (lease) => ready = lease,
    );
    final lease = await policy.bootstrapLease();
    final releaseAuthorization = Completer<void>();
    frame.nextProbeGate = releaseAuthorization;

    final admission = coordinator.admit(
      'markPrivilegedBridgeReady',
      {'privilegedCapability': lease?.capability},
    );
    await frame.waitForProbeCount(2);
    // authorize() consumes the first probe; hold revalidates() specifically.
    final releaseReadiness = Completer<void>();
    frame.nextProbeGate = releaseReadiness;
    releaseAuthorization.complete();
    await frame.waitForProbeCount(3);
    coordinator.noteDocumentLoadStarted();
    releaseReadiness.complete();

    final decision = await admission;
    expect(decision.dispatch, isFalse);
    expect(decision.error, contains('page changed'));
    expect(ready, isNull);
  });

  test('overlapping admitted handlers retain their own realm leases', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final secrets = _SecretSequence();
    final policy = _policy(frame, secrets: secrets);
    final coordinator = _coordinator(frame, policy: policy);
    final firstLease = await policy.bootstrapLease();
    final first = await coordinator.admit(
      'getSettingsState',
      {'privilegedCapability': firstLease?.capability},
    );
    frame.replaceDocument('${trustedUrl}settings');
    final secondLease = await policy.bootstrapLease();
    final second = await coordinator.admit(
      'getSettingsState',
      {'privilegedCapability': secondLease?.capability},
    );
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();

    final firstHandler = coordinator.runInRequestContext(
      admission: first,
      body: () async {
        await releaseFirst.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );
    final secondHandler = coordinator.runInRequestContext(
      admission: second,
      body: () async {
        await releaseSecond.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );

    releaseSecond.complete();
    expect(await secondHandler, secondLease?.capability);
    releaseFirst.complete();
    expect(await firstHandler, firstLease?.capability);
  });

  test('cached legacy shell is promoted by its first authorized call',
      () async {
    final frame = _AdmissionTopFrame(trustedUrl)
      ..supportsExplicitReadiness = false;
    final policy = _policy(frame);
    final ready = <PrivilegedBridgeLease>[];
    final coordinator = _coordinator(
      frame,
      policy: policy,
      onReady: ready.add,
    );
    final lease = await policy.bootstrapLease();

    final first = await coordinator.admit(
      'getSettingsState',
      {'privilegedCapability': lease?.capability},
    );
    final second = await coordinator.admit(
      'getProfileInfo',
      {'privilegedCapability': lease?.capability},
    );

    expect(first.dispatch, isTrue);
    expect(second.dispatch, isTrue);
    expect(ready, hasLength(1));
    expect(ready.single.marker, lease?.marker);
  });

  test('current shell waits for its explicit readiness handshake', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final policy = _policy(frame);
    final ready = <PrivilegedBridgeLease>[];
    final coordinator = _coordinator(
      frame,
      policy: policy,
      onReady: ready.add,
    );
    final lease = await policy.bootstrapLease();

    expect(
      (await coordinator.admit(
        'getSettingsState',
        {'privilegedCapability': lease?.capability},
      ))
          .dispatch,
      isTrue,
    );
    expect(ready, isEmpty);

    final handshake = await coordinator.admit(
      'markPrivilegedBridgeReady',
      {'privilegedCapability': lease?.capability},
    );
    expect(handshake.value, const {'ready': true});
    expect(ready, hasLength(1));

    final restoredHandshake = await coordinator.admit(
      'markPrivilegedBridgeReady',
      {'privilegedCapability': lease?.capability},
    );
    expect(restoredHandshake.value, const {'ready': true});
    expect(ready, hasLength(2),
        reason: 'an explicit same-realm pageshow must replay current state');
  });

  test('mixed-cache handshake falls back to the later legacy call', () async {
    final frame = _AdmissionTopFrame(trustedUrl)
      ..supportsExplicitReadiness = false;
    final policy = _policy(frame);
    final ready = <PrivilegedBridgeLease>[];
    final coordinator = _coordinator(
      frame,
      policy: policy,
      onReady: ready.add,
    );
    final lease = await policy.bootstrapLease();
    final payload = {'privilegedCapability': lease?.capability};

    final prematureHandshake = await coordinator.admit(
      'markPrivilegedBridgeReady',
      payload,
    );
    expect(prematureHandshake.value, const {'ready': false});
    expect(ready, isEmpty);

    final laterCall = await coordinator.admit('getSettingsState', payload);
    expect(laterCall.dispatch, isTrue);
    expect(ready, hasLength(1));
  });

  test('legacy realm replays after a provisional document load starts',
      () async {
    final frame = _AdmissionTopFrame(trustedUrl)
      ..supportsExplicitReadiness = false;
    final policy = _policy(frame);
    final ready = <PrivilegedBridgeLease>[];
    final coordinator = _coordinator(
      frame,
      policy: policy,
      onReady: ready.add,
    );
    final lease = await policy.bootstrapLease();
    final payload = {'privilegedCapability': lease?.capability};

    expect((await coordinator.admit('getSettingsState', payload)).dispatch,
        isTrue);
    coordinator.noteDocumentLoadStarted();
    expect((await coordinator.admit('getSettingsState', payload)).dispatch,
        isTrue);
    expect(ready, hasLength(2));
  });

  test('failed state replay keeps readiness retryable', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final policy = _policy(frame);
    var attempts = 0;
    final coordinator = BridgeAdmissionCoordinator(
      policy: policy,
      sessionGate: SessionHandoffGate(),
      admitAnonymousSession: () => true,
      markRealmReady: (_) async => ++attempts > 1,
    );
    final lease = await policy.bootstrapLease();
    final payload = {'privilegedCapability': lease?.capability};

    final first = await coordinator.admit(
      'markPrivilegedBridgeReady',
      payload,
    );
    final second = await coordinator.admit(
      'markPrivilegedBridgeReady',
      payload,
    );

    expect(first.error, contains('could not replay'));
    expect(second.value, const {'ready': true});
    expect(attempts, 2);
  });
}

PrivilegedBridgePolicy _policy(
  _AdmissionTopFrame frame, {
  _SecretSequence? secrets,
}) {
  final sequence = secrets ?? _SecretSequence();
  return PrivilegedBridgePolicy(
    trustedOrigin: Uri.parse('https://social-vibecoding.usernodelabs.org/'),
    allowLocalDevelopment: false,
    evaluateTopFrame: frame.evaluate,
    currentIdentity: () => const Identity(
      epoch: 1,
      phase: IdentityPhase.unauthenticated,
      sessionId: 'logged-out-test',
    ),
    sessionAuthority: SessionAuthorityGateway(),
    secretFactory: sequence.next,
    probeTimeout: const Duration(seconds: 1),
  );
}

final class _SecretSequence {
  int _next = 0;

  String next() => 'secret-${++_next}';
}

BridgeAdmissionCoordinator _coordinator(
  _AdmissionTopFrame frame, {
  PrivilegedBridgePolicy? policy,
  SessionHandoffGate? gate,
  void Function(PrivilegedBridgeLease lease)? onReady,
}) {
  return BridgeAdmissionCoordinator(
    policy: policy ?? _policy(frame),
    sessionGate: gate ?? SessionHandoffGate(),
    admitAnonymousSession: () => true,
    markRealmReady: (lease) async {
      (onReady ?? (_) {})(lease);
      return true;
    },
  );
}

final class _AdmissionTopFrame {
  _AdmissionTopFrame(this.href);

  String href;
  String? marker;
  bool supportsExplicitReadiness = true;
  Completer<void>? nextProbeGate;
  Completer<void>? _probeStarted;
  int probeCount = 0;

  Future<void> waitForProbeCount(int count) async {
    if (probeCount >= count) return;
    final started = _probeStarted ??= Completer<void>();
    await started.future;
    _probeStarted = null;
    if (probeCount < count) await waitForProbeCount(count);
  }

  Future<Object?> evaluate(String script) async {
    if (script.contains('Object.defineProperty(window, markerKey')) {
      probeCount++;
      marker ??= _extractDefinedValue(script);
      final currentMarker = marker!;
      final result = '${currentMarker.length}:$currentMarker$href';
      final gate = nextProbeGate;
      nextProbeGate = null;
      final started = _probeStarted;
      if (started != null && !started.isCompleted) started.complete();
      if (gate != null) await gate.future;
      return result;
    }
    if (script.contains('__usernodeExplicitReadinessClient')) {
      final expectedMarker = _extractExpectedMarker(script);
      if (marker != expectedMarker) return null;
      return supportsExplicitReadiness;
    }
    throw StateError('Unexpected evaluation');
  }

  void replaceDocument(String href) {
    this.href = href;
    marker = null;
  }

  static String _extractDefinedValue(String script) {
    final match = RegExp(r'value:\s*"([^"]+)"').firstMatch(script);
    if (match == null) throw StateError('missing marker candidate');
    return jsonDecode('"${match.group(1)}"') as String;
  }

  static String _extractExpectedMarker(String script) {
    final match =
        RegExp(r'window\[markerKey\] !== ("[^"]+")').firstMatch(script);
    if (match == null) throw StateError('missing marker guard');
    return jsonDecode(match.group(1)!) as String;
  }
}
