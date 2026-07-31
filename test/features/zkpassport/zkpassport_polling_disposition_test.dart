import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

class _ProofReadySessionServer extends ZkPassportSessionServerRepository {
  _ProofReadySessionServer() : super(baseUrl: 'https://example.test');

  final secondResultRequest = Completer<void>();
  int resultRequests = 0;
  int statusRequests = 0;

  @override
  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
    String? userPublicKey,
  }) async {
    resultRequests++;
    if (resultRequests == 2 && !secondResultRequest.isCompleted) {
      secondResultRequest.complete();
    }
    return null;
  }

  @override
  Future<ZkPassportSessionStatusResponse> getSessionStatus({
    required String sessionId,
    String? userPublicKey,
  }) async {
    statusRequests++;
    return ZkPassportSessionStatusResponse(
      sessionId: sessionId,
      status: 'result_ok',
      finalAvailable: false,
      updatedAtMs: 100,
    );
  }
}

class _ConsumptiveResultServer extends ZkPassportSessionServerRepository {
  _ConsumptiveResultServer() : super(baseUrl: 'https://example.test');

  final requestStarted = Completer<void>();
  final releaseResult = Completer<void>();
  int resultRequests = 0;

  @override
  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
    String? userPublicKey,
  }) async {
    resultRequests++;
    if (!requestStarted.isCompleted) requestStarted.complete();
    await releaseResult.future;
    return ZkPassportSessionResultResponse(
      sessionId: sessionId,
      status: 'result_ok',
      outerProofB64Url: 'durable-proof',
      nullifierHex: 'durable-nullifier',
      nullifierType: null,
      uniqueIdentifierType: null,
      oprfPkHash: null,
      error: null,
      finalizedAtMs: 100,
    );
  }
}

class _RejectedConsumptiveResultServer
    extends ZkPassportSessionServerRepository {
  _RejectedConsumptiveResultServer() : super(baseUrl: 'https://example.test');

  final requestStarted = Completer<void>();
  final releaseResult = Completer<void>();
  int resultRequests = 0;

  @override
  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
    String? userPublicKey,
  }) async {
    resultRequests++;
    if (!requestStarted.isCompleted) requestStarted.complete();
    if (resultRequests == 1) await releaseResult.future;
    return ZkPassportSessionResultResponse(
      sessionId: sessionId,
      status: 'result_error',
      outerProofB64Url: null,
      nullifierHex: null,
      nullifierType: null,
      uniqueIdentifierType: null,
      oprfPkHash: null,
      error: 'verification rejected',
      finalizedAtMs: 100,
    );
  }
}

class _FailFirstConsumedResultSave extends ZkPassportRuntimeSessionRepository {
  int consumedSaveAttempts = 0;

  @override
  Future<bool> saveIfCurrent(ZkPassportRuntimeSession session) {
    if (session.consumedResult != null && consumedSaveAttempts++ == 0) {
      throw StateError('injected consumed-result write failure');
    }
    return super.saveIfCurrent(session);
  }
}

ZkIdentityScope _scopeA() => ZkIdentityScope(
      network: NetworkPrefs.currentNetwork,
      bucket: NetworkPrefs.bucketForAddress('ut1-account-a'),
      participantId: 7,
      accountId: 'account-a',
      address: 'ut1-account-a',
      challengeId: 42,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkPrefs.setActiveBucket('ut1-account-a', guest: false);
    IdentitySnapshots.publish(const Identity(
      epoch: 3,
      phase: IdentityPhase.ready,
      participantId: 7,
      accountId: 'account-a',
      address: 'ut1-account-a',
    ));
  });

  tearDown(IdentitySnapshots.reset);

  test('result_ok status refetches result instead of failing the request',
      () async {
    final server = _ProofReadySessionServer();
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final controller = container.read(zkPassportPipelineProvider.notifier);
    final requestKey = await controller.markLaunchStarted(
      requestId: 'request-a',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );
    await controller.markLaunchDispatched(requestKey: requestKey);
    controller.startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );

    await server.secondResultRequest.future.timeout(const Duration(seconds: 2));

    expect(server.statusRequests, 1);
    expect(server.resultRequests, greaterThanOrEqualTo(2));
    expect(container.read(zkPassportPipelineProvider).status,
        ZkPassportPipelineStatus.processing);
  });

  test('identity switch detaches UI state without clearing owner runtime',
      () async {
    final currentIdentity = StateProvider<Identity>(
      (_) => IdentitySnapshots.current,
    );
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWith(
        (ref) => ref.watch(currentIdentity),
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(zkPassportPipelineProvider.notifier);
    await controller.markLaunchStarted(
      requestId: 'request-a',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );

    const replacement = Identity(
      epoch: 4,
      phase: IdentityPhase.ready,
      participantId: 8,
      accountId: 'account-b',
      address: 'ut1-account-b',
    );
    IdentitySnapshots.publish(replacement);
    container.read(currentIdentity.notifier).state = replacement;
    await pumpEventQueue();

    expect(
      container.read(zkPassportPipelineProvider).status,
      ZkPassportPipelineStatus.idle,
    );
    expect(
      await ZkPassportRuntimeSessionRepository().load(scope: _scopeA()),
      isNotNull,
    );
  });

  test('consumed result is persisted before an identity-switch gate', () async {
    final server = _ConsumptiveResultServer();
    final currentIdentity = StateProvider<Identity>(
      (_) => IdentitySnapshots.current,
    );
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWith(
        (ref) => ref.watch(currentIdentity),
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final controller = container.read(zkPassportPipelineProvider.notifier);
    final requestKey = await controller.markLaunchStarted(
      requestId: 'request-consumed',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );
    await controller.markLaunchDispatched(requestKey: requestKey);
    controller.startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );
    await server.requestStarted.future.timeout(const Duration(seconds: 2));

    const replacement = Identity(
      epoch: 4,
      phase: IdentityPhase.ready,
      participantId: 8,
      accountId: 'account-b',
      address: 'ut1-account-b',
    );
    IdentitySnapshots.publish(replacement);
    container.read(currentIdentity.notifier).state = replacement;
    server.releaseResult.complete();
    await pumpEventQueue();

    final persisted =
        await ZkPassportRuntimeSessionRepository().load(scope: _scopeA());
    expect(persisted?.requestVersion?.key, requestKey);
    expect(persisted?.consumedResult?.outerProofB64Url, 'durable-proof');
    expect(persisted?.consumedResult?.nullifierHex, 'durable-nullifier');
  });

  test('consumed result write failure retries without refetching result',
      () async {
    final server = _ConsumptiveResultServer();
    final runtimeRepo = _FailFirstConsumedResultSave();
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
      zkPassportRuntimeSessionRepositoryProvider.overrideWithValue(runtimeRepo),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final controller = container.read(zkPassportPipelineProvider.notifier);
    final requestKey = await controller.markLaunchStarted(
      requestId: 'request-write-failure',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );
    await controller.markLaunchDispatched(requestKey: requestKey);
    controller.startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );
    await server.requestStarted.future.timeout(const Duration(seconds: 2));

    server.releaseResult.complete();
    await pumpEventQueue();

    final persisted = await runtimeRepo.load(scope: _scopeA());
    expect(runtimeRepo.consumedSaveAttempts, 2);
    expect(server.resultRequests, 1);
    expect(persisted?.consumedResult?.outerProofB64Url, 'durable-proof');
  });

  test('a dormant consumed result resumes without refetching on foreground',
      () async {
    final server = _RejectedConsumptiveResultServer();
    final activeChallengeId = StateProvider<int?>((_) => 42);
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
      zkIdentityChallengeIdProvider.overrideWith(
        (ref) => ref.watch(activeChallengeId),
      ),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final controller = container.read(zkPassportPipelineProvider.notifier);
    final requestKey = await controller.markLaunchStarted(
      requestId: 'request-dormant-consumed',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );
    await controller.markLaunchDispatched(requestKey: requestKey);
    controller.startServerResultPolling(
      requestKey: requestKey,
      immediate: true,
    );
    await server.requestStarted.future.timeout(const Duration(seconds: 2));

    // The challenge can temporarily disappear while refreshed. The result is
    // still consumed and persisted, but proof/failure handling must defer.
    container.read(activeChallengeId.notifier).state = null;
    server.releaseResult.complete();
    await pumpEventQueue();
    expect(server.resultRequests, 1);

    container.read(activeChallengeId.notifier).state = 42;
    await controller.recoverPendingSessionOnForeground();
    await pumpEventQueue();

    expect(server.resultRequests, 1);
    expect(
      container.read(zkPassportPipelineProvider).status,
      ZkPassportPipelineStatus.failure,
    );
  });

  test('startup restoration prevents an immediate replacement launch',
      () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final scopedRestored = ZkPassportRuntimeSession(
      requestId: 'restored-request',
      facematchStrict: true,
      phase: ZkPassportPipelinePhase.waiting,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: 'restored-nonce',
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
    );
    await ZkPassportRuntimeSessionRepository().save(scopedRestored);
    final server = _ProofReadySessionServer();
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
      zkPassportSessionServerRepositoryProvider.overrideWithValue(server),
    ]);
    addTearDown(() {
      container.dispose();
      server.dispose();
    });

    final controller = container.read(zkPassportPipelineProvider.notifier);
    await controller.prepareForLaunch();
    expect(controller.activeRequestKey, scopedRestored.requestVersion?.key);
    await expectLater(
      controller.markLaunchStarted(
        requestId: 'replacement-request',
        facematchStrict: true,
        userPublicKey: 'public-key-a',
        launchScope: _scopeA(),
        launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
      ),
      throwsStateError,
    );
  });

  test('stale discard key cannot retire a replacement generation', () async {
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
      zkIdentityChallengeIdProvider.overrideWithValue(42),
    ]);
    addTearDown(container.dispose);

    final controller = container.read(zkPassportPipelineProvider.notifier);
    final staleKey = await controller.markLaunchStarted(
      requestId: 'reused-request',
      facematchStrict: true,
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
      launchAuthority: IdentityLease.capture(IdentitySnapshots.current),
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final replacement = ZkPassportRuntimeSession(
      requestId: staleKey.sessionId,
      facematchStrict: true,
      phase: ZkPassportPipelinePhase.waiting,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: 'replacement-nonce',
      userPublicKey: 'public-key-a',
      launchScope: _scopeA(),
    );
    await ZkPassportRuntimeSessionRepository().save(replacement);

    expect(
      await controller.discardPendingSession(
        requestKey: staleKey,
        requestId: staleKey.sessionId,
        reason: 'stale callback',
      ),
      isFalse,
    );
    expect(
      (await ZkPassportRuntimeSessionRepository().load(scope: _scopeA()))
          ?.requestVersion,
      replacement.requestVersion,
    );
  });
}
