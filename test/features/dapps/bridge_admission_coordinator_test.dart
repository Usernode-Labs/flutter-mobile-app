import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/features/dapps/bridge_admission_coordinator.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const trustedUrl = 'https://social-vibecoding.usernodelabs.org/';

  test('missing and invalid capabilities settle in the probed realm', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final secrets = _SecretSequence();
    final policy = _policy(frame, secrets: secrets);
    final coordinator = _coordinator(frame, policy: policy);

    for (final capability in <Object?>[null, '', 'guessed']) {
      PrivilegedBridgeLease? requestLease;
      final decision = await coordinator.runRequest(
        method: 'getSettingsState',
        payload: {'privilegedCapability': capability},
        body: (admission) async {
          requestLease = PrivilegedBridgeRequestContext.currentLease;
          return admission;
        },
      );
      expect(decision.dispatch, isFalse);
      expect(decision.lease, isNotNull);
      expect(decision.error, contains('requires a trusted'));
      expect(requestLease, same(decision.lease));
    }
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

    final admission = _admit(
      coordinator,
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
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final releaseSecond = Completer<void>();

    final firstHandler = coordinator.runRequest(
      method: 'getSettingsState',
      payload: {'privilegedCapability': firstLease?.capability},
      body: (_) async {
        firstStarted.complete();
        await releaseFirst.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );
    await firstStarted.future;
    frame.replaceDocument('${trustedUrl}settings');
    final secondLease = await policy.bootstrapLease();
    final secondHandler = coordinator.runRequest(
      method: 'getSettingsState',
      payload: {'privilegedCapability': secondLease?.capability},
      body: (_) async {
        await releaseSecond.future;
        return PrivilegedBridgeRequestContext.currentLease?.capability;
      },
    );

    releaseSecond.complete();
    expect(await secondHandler, secondLease?.capability);
    releaseFirst.complete();
    expect(await firstHandler, firstLease?.capability);
  });

  test('lifecycle handler blocks every later bridge admission', () async {
    for (final lifecycleMethod in ['logout', 'establishNativeSession']) {
      final frame = _AdmissionTopFrame(trustedUrl);
      final policy = _policy(frame);
      final coordinator = _coordinator(frame, policy: policy);
      final lease = await policy.bootstrapLease();
      final lifecycleStarted = Completer<void>();
      final releaseLifecycle = Completer<void>();
      var laterHandlerStarted = false;

      final lifecycle = coordinator.runRequest(
        method: lifecycleMethod,
        payload: {'privilegedCapability': lease?.capability},
        body: (_) async {
          lifecycleStarted.complete();
          await releaseLifecycle.future;
        },
      );
      await lifecycleStarted.future;
      final later = coordinator.runRequest(
        method: 'getSettingsState',
        payload: {'privilegedCapability': lease?.capability},
        body: (_) async {
          laterHandlerStarted = true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      expect(laterHandlerStarted, isFalse, reason: lifecycleMethod);

      releaseLifecycle.complete();
      await lifecycle;
      await later;
      expect(laterHandlerStarted, isTrue, reason: lifecycleMethod);
    }
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
      (await _admit(
        coordinator,
        'getSettingsState',
        {'privilegedCapability': lease?.capability},
      ))
          .dispatch,
      isTrue,
    );
    expect(ready, isEmpty);

    final handshake = await _admit(
      coordinator,
      'markPrivilegedBridgeReady',
      {'privilegedCapability': lease?.capability},
    );
    expect(handshake.value, const {'ready': true});
    expect(ready, hasLength(1));

    final restoredHandshake = await _admit(
      coordinator,
      'markPrivilegedBridgeReady',
      {'privilegedCapability': lease?.capability},
    );
    expect(restoredHandshake.value, const {'ready': true});
    expect(ready, hasLength(2),
        reason: 'an explicit same-realm pageshow must replay current state');
  });

  test('failed state replay keeps readiness retryable', () async {
    final frame = _AdmissionTopFrame(trustedUrl);
    final policy = _policy(frame);
    var attempts = 0;
    final coordinator = BridgeAdmissionCoordinator(
      policy: policy,
      markRealmReady: (_) async => ++attempts > 1,
    );
    final lease = await policy.bootstrapLease();
    final payload = {'privilegedCapability': lease?.capability};

    final first = await _admit(
      coordinator,
      'markPrivilegedBridgeReady',
      payload,
    );
    final second = await _admit(
      coordinator,
      'markPrivilegedBridgeReady',
      payload,
    );

    expect(first.error, contains('could not replay'));
    expect(second.value, const {'ready': true});
    expect(attempts, 2);
  });
}

Future<BridgeAdmissionDecision> _admit(
  BridgeAdmissionCoordinator coordinator,
  String method,
  Map<String, dynamic> payload,
) =>
    coordinator.runRequest(
      method: method,
      payload: payload,
      body: (admission) async => admission,
    );

PrivilegedBridgePolicy _policy(
  _AdmissionTopFrame frame, {
  _SecretSequence? secrets,
}) {
  final sequence = secrets ?? _SecretSequence();
  return PrivilegedBridgePolicy(
    trustedOrigin: Uri.parse('https://social-vibecoding.usernodelabs.org/'),
    allowLocalDevelopment: false,
    evaluateTopFrame: frame.evaluate,
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
  void Function(PrivilegedBridgeLease lease)? onReady,
}) {
  return BridgeAdmissionCoordinator(
    policy: policy ?? _policy(frame),
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
}
