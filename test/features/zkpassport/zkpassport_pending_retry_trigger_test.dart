import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

class _RecordingLeaderboardApiService extends LeaderboardApiService {
  _RecordingLeaderboardApiService()
      : super(baseUrl: 'https://example.test/api/v3/mobile');

  int completionCalls = 0;
  String? appSessionId;
  String? operationId;

  @override
  Future<bool> completeZkPassport({
    required String appSessionId,
    required String operationId,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    completionCalls++;
    this.appSessionId = appSessionId;
    this.operationId = operationId;
    return true;
  }
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 40 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Identity _ready({
  required int participantId,
  required String address,
  String? accountId,
  String? sessionId,
}) =>
    Identity(
      epoch: 3,
      phase: IdentityPhase.ready,
      participantId: participantId,
      accountId: accountId ?? 'account-$participantId',
      address: address,
      sessionId: sessionId ?? 'app-session-$participantId',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  tearDown(IdentitySnapshots.reset);

  test(
      'a launch is stamped with the identity that started it, not the one '
      'that happens to be current when the server answers', () async {
    const address = 'ut1-account-a';
    NetworkPrefs.setActiveBucket(address, guest: false);
    final launcher = _ready(participantId: 7, address: address);
    IdentitySnapshots.publish(launcher);

    final container = ProviderContainer(overrides: [
      // Reading the pipeline otherwise pulls in the challenges graph, which
      // builds `identityProvider` and republishes over the snapshot above.
      zkIdentityChallengeIdProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final pipeline = container.read(zkPassportPipelineProvider.notifier);

    // The session server call is unbounded network time; a sign-out plus a new
    // login inside it would otherwise have this stamp the SUCCESSOR onto A's
    // session, and every later scope check would then accept the wrong owner.
    IdentitySnapshots.publish(_ready(participantId: 8, address: 'ut1-b'));

    await expectLater(
      pipeline.markLaunchStarted(
        requestId: 'request-a',
        facematchStrict: true,
        userPublicKey: 'utpk1-a',
        launchIdentity: launcher,
      ),
      throwsA(isA<StateError>()),
    );

    // Nothing was persisted for either identity.
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.contains('runtime_session')),
      isEmpty,
    );
  });

  test('a launch whose identity is unchanged is accepted', () async {
    const address = 'ut1-account-a';
    NetworkPrefs.setActiveBucket(address, guest: false);
    final launcher = _ready(participantId: 7, address: address);
    IdentitySnapshots.publish(launcher);

    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final pipeline = container.read(zkPassportPipelineProvider.notifier);

    await pipeline.markLaunchStarted(
      requestId: 'request-a',
      facematchStrict: true,
      userPublicKey: 'utpk1-a',
      launchIdentity: launcher,
    );

    expect(
      container.read(zkPassportPipelineProvider).requestId,
      'request-a',
    );
    // Which bucket the stamped session is written to is covered by
    // `zkpassport_repositories_test.dart`.
  });

  test('a same-account successor cannot resume its predecessor runtime row',
      () async {
    const address = 'ut1-account-a';
    const participantId = 7;
    final bucket = NetworkPrefs.bucketForAddress(address);
    NetworkPrefs.setActiveBucket(address, guest: false);
    IdentitySnapshots.publish(_ready(
      participantId: participantId,
      address: address,
      sessionId: 'app-session-b',
    ));

    final runtimeRepo = ZkPassportRuntimeSessionRepository();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await runtimeRepo.save(ZkPassportRuntimeSession(
      appSessionId: 'app-session-a',
      requestId: 'request-a',
      facematchStrict: true,
      phase: ZkPassportPipelinePhase.waiting,
      createdAtMs: nowMs,
      lastProgressAtMs: nowMs,
      resumeAttemptCount: 0,
      requestNonce: 'nonce-a',
      launchBucket: bucket,
      launchParticipantId: participantId,
    ));

    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final pipeline = container.read(zkPassportPipelineProvider.notifier);

    await pipeline.recoverPendingSessionOnForeground();

    expect(
      container.read(zkPassportPipelineProvider).status,
      ZkPassportPipelineStatus.failure,
    );
    expect(await runtimeRepo.load(), isNull);
  });

  test('challenge id becoming available retriggers a deferred outbox retry',
      () async {
    const accountId = 'account-a';
    const address = 'ut1-account-a';
    const participantId = 7;
    const challengeId = 42;
    const version = ZkPassportRequestVersion(
      requestId: 'request-a',
      createdAtMs: 100,
      nonce: 'nonce-a',
    );
    final bucket = NetworkPrefs.bucketForAddress(address);
    NetworkPrefs.setActiveBucket(address, guest: false);
    IdentitySnapshots.publish(_ready(
      participantId: participantId,
      address: address,
      accountId: accountId,
      sessionId: 'app-session-a',
    ));

    final registrationRepo = ZkPassportRegistrationRepository();
    await registrationRepo.storePendingCompletion(
      appSessionId: 'app-session-a',
      participantId: participantId,
      challengeId: challengeId,
      walletAddress: address,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
      accountId: accountId,
      bucket: bucket,
    );

    final activeChallengeId = StateProvider<int?>((_) => null);
    final api = _RecordingLeaderboardApiService();
    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWith(
        (ref) => ref.watch(activeChallengeId),
      ),
      leaderboardApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(() {
      container.dispose();
      api.dispose();
    });

    container.read(zkPassportPipelineProvider.notifier);
    await _pumpUntil(() => api.completionCalls != 0);
    expect(api.completionCalls, 0);
    expect(
      await registrationRepo.getPendingCompletion(bucket: bucket),
      isNotNull,
    );

    container.read(activeChallengeId.notifier).state = challengeId;
    await _pumpUntil(() => api.completionCalls == 1);

    expect(api.completionCalls, 1);
    expect(api.appSessionId, 'app-session-a');
    expect(
      api.operationId,
      'zk-delivery:app-session-a:request-a:100:nonce-a',
    );
    expect(
      await registrationRepo.getPendingCompletion(bucket: bucket),
      isNull,
    );
  });

  test('a successor app session cannot retry its predecessor outbox', () async {
    const address = 'ut1-account-a';
    const participantId = 7;
    const challengeId = 42;
    const version = ZkPassportRequestVersion(
      requestId: 'request-a',
      createdAtMs: 100,
      nonce: 'nonce-a',
    );
    final bucket = NetworkPrefs.bucketForAddress(address);
    NetworkPrefs.setActiveBucket(address, guest: false);
    IdentitySnapshots.publish(_ready(
      participantId: participantId,
      address: address,
      sessionId: 'app-session-b',
    ));

    final registrationRepo = ZkPassportRegistrationRepository();
    await registrationRepo.storePendingCompletion(
      appSessionId: 'app-session-a',
      participantId: participantId,
      challengeId: challengeId,
      walletAddress: address,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
      accountId: 'account-$participantId',
      bucket: bucket,
    );

    final api = _RecordingLeaderboardApiService();
    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWithValue(challengeId),
      leaderboardApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(() {
      container.dispose();
      api.dispose();
    });

    container.read(zkPassportPipelineProvider.notifier);
    await _pumpUntil(() => api.completionCalls != 0);

    expect(api.completionCalls, 0);
    expect(
      await registrationRepo.getPendingCompletion(bucket: bucket),
      isNotNull,
    );
  });
}
