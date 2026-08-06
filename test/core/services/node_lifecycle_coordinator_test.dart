import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/node_runtime_binding.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

const NodeRuntimeConfiguration testConfiguration = (
  network: 'testnet',
  seedlistUrl: 'https://seed.example',
  genesisUrl: 'https://genesis.example',
  viewOnly: false,
  enableRealProver: false,
  observabilityHubBaseUrl: '',
  operatingSystem: 'android',
);

NodeRuntimeBinding testBinding({
  IdentityPhase phase = IdentityPhase.ready,
  int? participantId = 10,
  String? accountId,
  String? address,
  int? seasonId,
  bool released = true,
}) =>
    (
      identityPhase: phase,
      participantId: participantId,
      accountId: accountId,
      address: address,
      provisionedSeasonId: seasonId,
      blockProductionReleased: released,
      configuration: testConfiguration,
    );

final bindingA = testBinding(
  accountId: 'account-a',
  address: 'address-a',
  seasonId: 7,
);

final bindingB = testBinding(
  accountId: 'account-b',
  address: 'address-b',
  seasonId: 8,
);

final bindingARevoked = testBinding(
  accountId: 'account-a',
  address: 'address-a',
  seasonId: 7,
  released: false,
);

final guestBinding = testBinding(
  phase: IdentityPhase.guest,
  participantId: null,
  released: false,
);

const identityA = Identity(
  epoch: 1,
  phase: IdentityPhase.ready,
  participantId: 10,
  accountId: 'account-a',
  address: 'address-a',
  provisionedSeasonId: 7,
);

const identityB = Identity(
  epoch: 2,
  phase: IdentityPhase.ready,
  participantId: 10,
  accountId: 'account-b',
  address: 'address-b',
  provisionedSeasonId: 8,
);

const restoredIdentityA = Identity(
  epoch: 99,
  phase: IdentityPhase.ready,
  participantId: 10,
  accountId: 'account-a',
  address: 'address-a',
  provisionedSeasonId: 7,
);

const guestIdentity = Identity(
  epoch: 3,
  phase: IdentityPhase.guest,
);

class _BackendHarness {
  final calls = <String>[];
  bool running = false;
  bool sleeping = false;
  NodeRuntimeBinding? binding;
  NodeRuntimeAuthority? authority;
  Completer<void>? startEntered;
  Completer<void>? startGate;
  bool startResult = true;
  void Function()? afterStart;
  int? lastRetireThroughGeneration;

  Future<bool> start(
    NodeRuntimeBinding requested,
    NodeRuntimeAuthority? requestedAuthority,
  ) async {
    calls.add(
        'start:${requested.accountId}:${requested.blockProductionReleased}');
    final entered = startEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await startGate?.future;
    if (!startResult) return false;
    running = true;
    binding = requested;
    authority = requestedAuthority;
    afterStart?.call();
    return true;
  }

  Future<void> stop(int? retireThroughGeneration) async {
    calls.add('stopBackend');
    lastRetireThroughGeneration = retireThroughGeneration;
    running = false;
    binding = null;
    authority = null;
  }

  Future<void> pause() async => calls.add('pauseBackend');

  Future<void> resume() async => calls.add('resumeBackend');
}

void main() {
  late _BackendHarness backend;
  late Map<int, NodeRuntimeBinding?> resolvedBindings;
  late NodeRecoveryLease recoveryLease;
  Completer<void>? bindingResolutionEntered;
  Completer<void>? bindingResolutionGate;
  Completer<void>? reserveEntered;
  Completer<void>? reserveGate;
  void Function()? afterNodeStarted;
  var reserveCalls = 0;
  var revokeCalls = 0;

  NodeLifecycleCoordinator build({
    required bool android,
    NodeRecoveryLease initialRecoveryLease = const NodeRecoveryLease.disabled(),
    bool canRebindAuthority = true,
  }) {
    backend = _BackendHarness();
    resolvedBindings = {
      identityA.epoch: bindingA,
      identityB.epoch: bindingB,
      restoredIdentityA.epoch: bindingA,
      guestIdentity.epoch: guestBinding,
    };
    recoveryLease = initialRecoveryLease;
    bindingResolutionEntered = null;
    bindingResolutionGate = null;
    reserveEntered = null;
    reserveGate = null;
    afterNodeStarted = null;
    reserveCalls = 0;
    revokeCalls = 0;
    final coordinator = NodeLifecycleCoordinator(
      startBackend: backend.start,
      stopBackend: backend.stop,
      pauseBackend: backend.pause,
      resumeBackend: backend.resume,
      isNodeRunning: () => backend.running,
      runningBinding: () => backend.binding,
      runningAuthority: () => backend.authority,
      resolveBinding: (identity) async {
        final entered = bindingResolutionEntered;
        if (entered != null && !entered.isCompleted) {
          entered.complete();
        }
        await bindingResolutionGate?.future;
        return resolvedBindings[identity.epoch];
      },
      isSleeping: () => backend.sleeping,
      enableWatchdogRecovery: () => backend.calls.add('enableRecovery'),
      disableWatchdogRecovery: () => backend.calls.add('disableRecovery'),
      auditBestEffort: ({required String reason}) =>
          backend.calls.add('audit:$reason'),
      onNodeStarted: (_) async {
        backend.calls.add('onNodeStarted');
        afterNodeStarted?.call();
      },
      stopMonitoring: ({
        required String reason,
        required NodeRuntimeAuthority? authority,
      }) async =>
          backend.calls.add('stopMonitoring:$reason'),
      loadRecoveryLease: () async => recoveryLease,
      reserveRuntimeBinding: (fingerprint, expectedLease) async {
        reserveCalls += 1;
        final entered = reserveEntered;
        if (entered != null && !entered.isCompleted) {
          entered.complete();
        }
        await reserveGate?.future;
        if (!recoveryLease.sameCursorAs(expectedLease)) {
          return NodeRecoveryLeaseMutation(
            lease: recoveryLease,
            accepted: false,
          );
        }
        if (recoveryLease.bindingFingerprint != fingerprint) {
          recoveryLease = NodeRecoveryLease(
            enabled: false,
            generation: recoveryLease.generation + 1,
            bindingFingerprint: fingerprint,
          );
        }
        return NodeRecoveryLeaseMutation.accepted(recoveryLease);
      },
      activateRecoveryLease: (authority) async {
        if (!recoveryLease.matchesAuthority(authority)) {
          return NodeRecoveryLeaseMutation(
            lease: recoveryLease,
            accepted: false,
          );
        }
        if (!recoveryLease.enabled &&
            recoveryLease.bindingFingerprint != null) {
          recoveryLease = NodeRecoveryLease(
            enabled: true,
            generation: recoveryLease.generation,
            bindingFingerprint: recoveryLease.bindingFingerprint,
          );
        }
        return NodeRecoveryLeaseMutation.accepted(recoveryLease);
      },
      disableRecoveryLease: (authority) async {
        if (!recoveryLease.matchesAuthority(authority)) {
          return NodeRecoveryLeaseMutation(
            lease: recoveryLease,
            accepted: false,
          );
        }
        if (recoveryLease.bindingFingerprint != null) {
          recoveryLease = NodeRecoveryLease(
            enabled: false,
            generation: recoveryLease.generation,
            bindingFingerprint: recoveryLease.bindingFingerprint,
          );
        }
        return NodeRecoveryLeaseMutation.accepted(recoveryLease);
      },
      revokeRecoveryLease: (expectedLease) async {
        revokeCalls += 1;
        if (!recoveryLease.sameCursorAs(expectedLease)) {
          return NodeRecoveryLeaseMutation(
            lease: recoveryLease,
            accepted: false,
          );
        }
        recoveryLease = NodeRecoveryLease.disabled(
          generation: recoveryLease.generation + 1,
        );
        return NodeRecoveryLeaseMutation.accepted(recoveryLease);
      },
      isAndroid: () => android,
    );
    if (android) {
      coordinator.initializeAndroidAuthority(
        recoveryLease,
        canRebind: canRebindAuthority,
      );
    }
    return coordinator;
  }

  setUp(() {
    IdentitySnapshots.reset();
  });

  tearDown(IdentitySnapshots.reset);

  test('successful Android start binds runtime before wiring production',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);

    expect(await coordinator.startNode(reason: 'platform_start'), isTrue);

    expect(backend.binding, bindingA);
    expect(backend.calls, [
      'start:account-a:true',
      'enableRecovery',
      'onNodeStarted',
      'audit:platform_start',
    ]);
  });

  test('superseded reservation still advances the owned authority cursor',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    reserveEntered = Completer<void>();
    reserveGate = Completer<void>();

    final firstStart = coordinator.startNode(reason: 'first_start');
    await reserveEntered!.future;
    final latestStart = coordinator.startNode(reason: 'latest_start');
    reserveGate!.complete();

    expect(await firstStart, isFalse);
    expect(await latestStart, isTrue);
    expect(reserveCalls, 1);
    expect(coordinator.ownedAndroidLease?.generation, 1);
    expect(
      backend.calls.where((call) => call.startsWith('start:')),
      ['start:account-a:true'],
    );
  });

  test('settled guest start runs keylessly without arming recovery', () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(guestIdentity);

    expect(await coordinator.startNode(reason: 'guest_start'), isTrue);

    expect(backend.binding, guestBinding);
    expect(coordinator.desired.recoveryArmed, isFalse);
    expect(recoveryLease.enabled, isFalse);
  });

  test('same binding is reused without rebuilding', () async {
    final coordinator = build(android: false);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    backend.calls.clear();

    await coordinator.reportIdentityChanged(identityA, reason: 'refresh');

    expect(backend.calls, ['resumeBackend']);
  });

  test('season rollover stops old binding and starts new binding automatically',
      () async {
    final coordinator = build(android: false);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    backend.calls.clear();

    final reconciling = identityA.copyWith(
      epoch: 2,
      phase: IdentityPhase.reconciling,
    );
    resolvedBindings[reconciling.epoch] = null;
    IdentitySnapshots.publish(reconciling);
    await coordinator.reportIdentityChanged(
      reconciling,
      reason: 'season_rollover',
    );

    resolvedBindings[identityB.epoch] = bindingB;
    IdentitySnapshots.publish(identityB);
    await coordinator.reportIdentityChanged(identityB, reason: 'ready');

    expect(backend.calls, [
      'stopBackend',
      'start:account-b:true',
    ]);
    expect(coordinator.intent, PlatformNodeIntent.start);
    expect(backend.binding, bindingB);
  });

  test('release revocation rebuilds as non-producing and disarms Android',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    backend.calls.clear();
    resolvedBindings[identityA.epoch] = bindingARevoked;

    await coordinator.reportIdentityChanged(
      identityA,
      reason: 'authority_refresh',
    );

    expect(backend.binding, bindingARevoked);
    expect(backend.calls, [
      'disableRecovery',
      'stopMonitoring:binding_changed:authority_refresh',
      'stopBackend',
      'start:account-a:false',
      'disableRecovery',
      'stopMonitoring:authority_refresh',
    ]);
  });

  test('release revocation disarms recovery even without a running node',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 4,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);
    await coordinator.reportColdBoot();
    backend.calls.clear();
    resolvedBindings[identityA.epoch] = bindingARevoked;

    await coordinator.reportIdentityChanged(
      identityA,
      reason: 'authority_revoked',
    );

    expect(recoveryLease.enabled, isFalse);
    expect(backend.running, isFalse);
    expect(backend.calls, [
      'disableRecovery',
      'stopMonitoring:authority_revoked',
      'stopBackend',
    ]);
  });

  test('delayed older identity report cannot override a newer platform start',
      () async {
    final coordinator = build(android: false);
    bindingResolutionEntered = Completer<void>();
    bindingResolutionGate = Completer<void>();

    IdentitySnapshots.publish(identityA);
    final oldReport = coordinator.reportIdentityChanged(
      identityA,
      reason: 'delayed_boot',
    );
    await bindingResolutionEntered!.future;

    IdentitySnapshots.publish(identityB);
    final start = coordinator.startNode(reason: 'platform_start');
    bindingResolutionGate!.complete();
    await oldReport;
    expect(await start, isTrue);

    expect(coordinator.binding, bindingB);
    expect(backend.binding, bindingB);
    expect(backend.calls.where((call) => call.startsWith('stop')), isEmpty);
  });

  test('stop supersedes an in-flight start before support can be armed',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    backend.startEntered = Completer<void>();
    backend.startGate = Completer<void>();

    final start = coordinator.startNode(reason: 'platform_start');
    await backend.startEntered!.future;
    final stop = coordinator.stopNode(reason: 'platform_stop');
    backend.startGate!.complete();

    expect(await start, isFalse);
    await stop;

    expect(backend.running, isFalse);
    expect(backend.calls, isNot(contains('enableRecovery')));
    expect(backend.calls, isNot(contains('onNodeStarted')));
  });

  test('binding refresh supersedes an in-flight start before activation',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    backend.startEntered = Completer<void>();
    backend.startGate = Completer<void>();

    final start = coordinator.startNode(reason: 'platform_start');
    await backend.startEntered!.future;
    resolvedBindings[identityA.epoch] = bindingARevoked;
    final refresh = coordinator.reportIdentityChanged(
      identityA,
      reason: 'authority_refresh',
    );
    backend.startGate!.complete();

    expect(await start, isFalse);
    await refresh;

    expect(backend.binding, bindingARevoked);
    expect(backend.calls, isNot(contains('enableRecovery')));
    expect(backend.calls, isNot(contains('onNodeStarted')));
    expect(recoveryLease.enabled, isFalse);
  });

  test('hard logout closes admission and drains an in-flight start', () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    backend.startEntered = Completer<void>();
    backend.startGate = Completer<void>();

    final start = coordinator.startNode(reason: 'platform_start');
    await backend.startEntered!.future;
    final logout = coordinator.hardStopForSessionBoundary(reason: 'logout');
    backend.startGate!.complete();

    expect(await start, isFalse);
    await logout;
    expect(coordinator.acceptingRuntimeWork, isFalse);
    expect(backend.running, isFalse);
    expect(await coordinator.startNode(reason: 'stale_bridge'), isFalse);
  });

  test('hard logout is not blocked by stale binding resolution', () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    bindingResolutionEntered = Completer<void>();
    bindingResolutionGate = Completer<void>();

    final start = coordinator.startNode(reason: 'platform_start');
    await bindingResolutionEntered!.future;

    await coordinator.hardStopForSessionBoundary(reason: 'logout');
    expect(coordinator.acceptingRuntimeWork, isFalse);

    bindingResolutionGate!.complete();
    expect(await start, isFalse);
    expect(backend.calls.where((call) => call.startsWith('start:')), isEmpty);
  });

  test('hard logout waits for every production support path to disarm',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    backend.calls.clear();

    await coordinator.hardStopForSessionBoundary(reason: 'logout');

    expect(backend.calls, [
      'disableRecovery',
      'stopMonitoring:logout',
      'stopBackend',
    ]);
  });

  test('platform stop is not undone by sleep wake', () async {
    final coordinator = build(android: false);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    await coordinator.stopNode(reason: 'platform_stop');
    backend.calls.clear();

    await coordinator.reportSleepChanged(sleeping: true, reason: 'sleep');
    await coordinator.reportSleepChanged(sleeping: false, reason: 'wake');

    expect(backend.running, isFalse);
    expect(backend.calls.where((call) => call.startsWith('start:')), isEmpty);
  });

  test('resume after session boundary requires a fresh ready binding',
      () async {
    final coordinator = build(android: false);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    await coordinator.hardStopForSessionBoundary(reason: 'logout');
    backend.calls.clear();

    coordinator.resumeAfterSessionBoundary();

    expect(coordinator.binding, isNull);
    expect(coordinator.intent, PlatformNodeIntent.unset);
    expect(backend.calls, isEmpty);
  });

  test('stale cold boot completion cannot disarm a newer platform start',
      () async {
    final coordinator = build(android: true);
    bindingResolutionEntered = Completer<void>();
    bindingResolutionGate = Completer<void>();
    IdentitySnapshots.publish(identityA);

    final coldBoot = coordinator.reportColdBoot();
    await bindingResolutionEntered!.future;
    final start = coordinator.startNode(reason: 'platform_start');
    bindingResolutionGate!.complete();
    await coldBoot;
    expect(await start, isTrue);

    expect(coordinator.intent, PlatformNodeIntent.start);
    expect(coordinator.desired.recoveryArmed, isTrue);
    expect(backend.binding, bindingA);
  });

  test('cold boot cannot mutate authority advanced during binding resolution',
      () async {
    final capturedLease = NodeRecoveryLease(
      enabled: true,
      generation: 10,
      bindingFingerprint: bindingB.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: capturedLease,
    );
    IdentitySnapshots.publish(identityA);
    bindingResolutionEntered = Completer<void>();
    bindingResolutionGate = Completer<void>();

    final coldBoot = coordinator.reportColdBoot();
    await bindingResolutionEntered!.future;
    recoveryLease = NodeRecoveryLease(
      enabled: true,
      generation: 11,
      bindingFingerprint: bindingB.recoveryFingerprint,
    );
    bindingResolutionGate!.complete();

    expect(await coldBoot, isFalse);
    expect(reserveCalls, 1);
    expect(revokeCalls, 0);
    expect(recoveryLease.generation, 11);
    expect(recoveryLease.bindingFingerprint, bindingB.recoveryFingerprint);
    expect(coordinator.desired.authority, isNull);
  });

  test('headless cold boot can invalidate but cannot rebind authority',
      () async {
    final capturedLease = NodeRecoveryLease(
      enabled: true,
      generation: 20,
      bindingFingerprint: bindingB.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: capturedLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);

    expect(await coordinator.reportColdBoot(), isFalse);
    expect(revokeCalls, 1);
    expect(reserveCalls, 0);
    expect(recoveryLease.enabled, isFalse);
    expect(recoveryLease.bindingFingerprint, isNull);
    expect(coordinator.desired.authority, isNull);
  });

  test('logout invalidates a queued watchdog generation', () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    await coordinator.startNode(reason: 'platform_start');
    final staleEvent = <String, dynamic>{
      'recoveryGeneration': recoveryLease.generation,
      'bindingFingerprint': recoveryLease.bindingFingerprint,
    };

    await coordinator.hardStopForSessionBoundary(reason: 'logout');
    backend.calls.clear();

    expect(
      await coordinator.recoverFromNativeEvent(
        staleEvent,
        reason: 'workmanager',
      ),
      NodeNativeRecoveryResult.rejected,
    );
    expect(backend.calls.where((call) => call.startsWith('start:')), isEmpty);
    expect(recoveryLease.enabled, isFalse);
  });

  test('matching persisted lease authorizes a headless cold-boot recovery',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 4,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);

    expect(await coordinator.reportColdBoot(), isFalse);
    expect(backend.running, isFalse);
    await coordinator.reportIdentityChanged(identityA);
    expect(coordinator.desired.recoveryArmed, isTrue);

    expect(
      await coordinator.recoverFromNativeEvent(
        {
          'recoveryGeneration': 4,
          'bindingFingerprint': bindingA.recoveryFingerprint,
        },
        reason: 'workmanager',
      ),
      NodeNativeRecoveryResult.recovered,
    );
    expect(backend.binding, bindingA);
    expect(backend.calls, isNot(contains('audit:workmanager')));
  });

  test('authorized recovery start failure preserves authority for retry',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 5,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);
    await coordinator.reportColdBoot();
    backend.startResult = false;

    final result = await coordinator.recoverFromNativeEvent(
      {
        'recoveryGeneration': 5,
        'bindingFingerprint': bindingA.recoveryFingerprint,
      },
      reason: 'workmanager',
    );

    expect(result, NodeNativeRecoveryResult.retryableFailure);
    expect(recoveryLease.enabled, isTrue);
    expect(coordinator.desired.recoveryRunRequested, isTrue);
    expect(backend.calls, isNot(contains('disableRecovery')));
  });

  test('foreground wake retires the recovery override before the next sleep',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 6,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);
    backend.sleeping = true;
    await coordinator.reportColdBoot();
    expect(
      await coordinator.recoverFromNativeEvent(
        {
          'recoveryGeneration': 6,
          'bindingFingerprint': bindingA.recoveryFingerprint,
        },
        reason: 'alarm',
      ),
      NodeNativeRecoveryResult.recovered,
    );
    expect(coordinator.desired.recoveryRunRequested, isTrue);

    await coordinator.reportSleepChanged(sleeping: false, reason: 'wake');
    expect(coordinator.desired.recoveryRunRequested, isFalse);
    backend.calls.clear();

    await coordinator.reportSleepChanged(sleeping: true, reason: 'sleep');
    expect(backend.calls, contains('pauseBackend'));
  });

  test('ordinary sleep retires recovery delivered while already awake',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 7,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);
    await coordinator.reportColdBoot();

    expect(
      await coordinator.recoverFromNativeEvent(
        {
          'recoveryGeneration': 7,
          'bindingFingerprint': bindingA.recoveryFingerprint,
        },
        reason: 'workmanager',
      ),
      NodeNativeRecoveryResult.recovered,
    );
    expect(coordinator.desired.recoveryRunRequested, isTrue);
    backend.calls.clear();

    await coordinator.reportSleepChanged(sleeping: true, reason: 'sleep');

    expect(coordinator.desired.recoveryRunRequested, isFalse);
    expect(backend.calls, contains('pauseBackend'));
  });

  test('completed headless recovery pauses without revoking its lease',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 8,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
      canRebindAuthority: false,
    );
    IdentitySnapshots.publish(identityA);
    backend.sleeping = true;
    await coordinator.reportColdBoot();
    await coordinator.recoverFromNativeEvent(
      {
        'recoveryGeneration': 8,
        'bindingFingerprint': bindingA.recoveryFingerprint,
      },
      reason: 'workmanager',
    );
    final authority = coordinator.desired.authority!;
    backend.calls.clear();

    await coordinator.completeRecoveryRun(authority: authority);

    expect(coordinator.desired.recoveryRunRequested, isFalse);
    expect(backend.calls, contains('pauseBackend'));
    expect(backend.calls, isNot(contains('disableRecovery')));
    expect(recoveryLease.enabled, isTrue);
  });

  test('cold boot accepts a stable lease after the identity epoch resets',
      () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 8,
      bindingFingerprint: bindingA.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
    );
    IdentitySnapshots.publish(restoredIdentityA);

    expect(await coordinator.reportColdBoot(), isFalse);
    expect(coordinator.binding, bindingA);
    expect(coordinator.desired.recoveryArmed, isTrue);
  });

  test('cold boot revokes a durable lease for a different binding', () async {
    final initialLease = NodeRecoveryLease(
      enabled: true,
      generation: 12,
      bindingFingerprint: bindingB.recoveryFingerprint,
    );
    final coordinator = build(
      android: true,
      initialRecoveryLease: initialLease,
    );
    IdentitySnapshots.publish(identityA);

    expect(await coordinator.reportColdBoot(), isFalse);

    expect(recoveryLease.enabled, isFalse);
    expect(recoveryLease.generation, 13);
    expect(
      recoveryLease.bindingFingerprint,
      bindingA.recoveryFingerprint,
    );
    expect(backend.lastRetireThroughGeneration, 12);
    expect(coordinator.desired.recoveryArmed, isFalse);
  });

  test('an older coordinator cannot adopt a newer same-binding generation',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    expect(await coordinator.startNode(reason: 'first_start'), isTrue);
    final oldAuthority = coordinator.desired.authority!;

    recoveryLease = NodeRecoveryLease(
      enabled: true,
      generation: oldAuthority.generation + 2,
      bindingFingerprint: oldAuthority.bindingFingerprint,
    );
    backend.running = false;
    backend.binding = null;
    backend.authority = null;

    expect(
      await coordinator.recoverFromCurrentLease(reason: 'stale_audit'),
      isFalse,
    );
    expect(await coordinator.startNode(reason: 'stale_start'), isFalse);
    expect(coordinator.desired.authority!.generation, oldAuthority.generation);
    expect(recoveryLease.enabled, isTrue);
  });

  test('a start superseded before activation retires only its generation',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    backend.afterStart = () {
      recoveryLease = NodeRecoveryLease(
        enabled: true,
        generation: recoveryLease.generation + 2,
        bindingFingerprint: recoveryLease.bindingFingerprint,
      );
    };

    expect(await coordinator.startNode(reason: 'superseded_start'), isFalse);

    expect(backend.running, isFalse);
    expect(backend.lastRetireThroughGeneration, 1);
    expect(backend.calls, isNot(contains('onNodeStarted')));
    expect(recoveryLease.generation, 3);
    expect(recoveryLease.enabled, isTrue);
  });

  test('authority loss after monitoring starts tears down local support',
      () async {
    final coordinator = build(android: true);
    IdentitySnapshots.publish(identityA);
    afterNodeStarted = () {
      recoveryLease = NodeRecoveryLease(
        enabled: true,
        generation: recoveryLease.generation + 2,
        bindingFingerprint: bindingB.recoveryFingerprint,
      );
    };

    expect(
        await coordinator.startNode(reason: 'superseded_monitoring'), isFalse);

    expect(backend.running, isFalse);
    expect(
      backend.calls,
      contains(
        'stopMonitoring:'
        'runtime_authority_superseded:superseded_monitoring',
      ),
    );
    expect(backend.lastRetireThroughGeneration, 1);
    expect(recoveryLease.generation, 3);
    expect(recoveryLease.bindingFingerprint, bindingB.recoveryFingerprint);
  });
}
