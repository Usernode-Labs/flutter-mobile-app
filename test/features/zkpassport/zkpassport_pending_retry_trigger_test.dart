import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
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

  @override
  Future<bool> completeZkPassport({
    required String appSessionId,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    completionCalls++;
    this.appSessionId = appSessionId;
    return true;
  }
}

const _namespace = 'aaaaaaaaaaaaaaaa';

Future<AccountCapability> _seedAccount(Identity identity) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('testnet:identity:namespace', _namespace);
  await prefs.setString(
    'testnet:user:$_namespace:accounts:index',
    '[{"id":"${identity.accountId}","name":"Test",'
        '"createdAt":"2026-01-01T00:00:00.000Z",'
        '"derivationPath":"test","hdIndex":0,'
        '"address":"${identity.address}","publicKey":"utpk1-test",'
        '"backupConfirmed":true,"isDemo":true}]',
  );
  await prefs.setString(
    'testnet:user:$_namespace:accounts:activeId',
    identity.accountId!,
  );
  final accounts = await AccountsRepository.create();
  return accounts.capabilityFor(identity);
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

  test('a late launch write remains owned by the captured application session',
      () async {
    const address = 'ut1-account-a';
    NetworkPrefs.setActiveBucket(address, guest: false);
    final launcher = _ready(participantId: 7, address: address);
    IdentitySnapshots.publish(launcher);
    final launchCapability = await _seedAccount(launcher);

    final container = ProviderContainer(overrides: [
      // Reading the pipeline otherwise pulls in the challenges graph, which
      // builds `identityProvider` and republishes over the snapshot above.
      zkIdentityChallengeIdProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final pipeline = container.read(zkPassportPipelineProvider.notifier);

    IdentitySnapshots.publish(_ready(participantId: 8, address: 'ut1-b'));

    await pipeline.markLaunchStarted(
      requestId: 'request-a',
      facematchStrict: true,
      userPublicKey: 'utpk1-a',
      launchIdentity: launcher,
      launchCapability: launchCapability,
    );

    expect(
      (await ZkPassportRuntimeSessionRepository().loadForSession(
        appSessionId: launcher.sessionId!,
        network: launchCapability.network,
        bucket: launchCapability.bucket,
      ))
          ?.requestId,
      'request-a',
    );
  });

  test('a launch whose identity is unchanged is accepted', () async {
    const address = 'ut1-account-a';
    NetworkPrefs.setActiveBucket(address, guest: false);
    final launcher = _ready(participantId: 7, address: address);
    IdentitySnapshots.publish(launcher);
    final launchCapability = await _seedAccount(launcher);

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
      launchCapability: launchCapability,
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
    await _seedAccount(IdentitySnapshots.current);

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
      launchNetwork: 'testnet',
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
      ZkPassportPipelineStatus.idle,
    );
    expect(
      await runtimeRepo.loadForSession(
        appSessionId: 'app-session-a',
        network: 'testnet',
        bucket: bucket,
      ),
      isNotNull,
    );
  });

  test(
      'an exact-session outbox retry does not depend on ambient challenge load',
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
    NetworkPrefs.setActiveBucket(address, guest: false);
    final identity = _ready(
      participantId: participantId,
      address: address,
      accountId: accountId,
      sessionId: 'app-session-a',
    );
    IdentitySnapshots.publish(identity);
    final capability = await _seedAccount(identity);

    final registrationRepo = ZkPassportRegistrationRepository();
    await registrationRepo.storePendingCompletion(
      capability: capability,
      participantId: participantId,
      challengeId: challengeId,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
    );

    final api = _RecordingLeaderboardApiService();
    final container = ProviderContainer(overrides: [
      zkIdentityChallengeIdProvider.overrideWithValue(null),
      leaderboardApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(() {
      container.dispose();
      api.dispose();
    });

    container.read(zkPassportPipelineProvider.notifier);
    await _pumpUntil(() => api.completionCalls == 1);

    expect(api.completionCalls, 1);
    expect(api.appSessionId, 'app-session-a');
    expect(await registrationRepo.getPendingCompletion(capability), isNull);
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
    NetworkPrefs.setActiveBucket(address, guest: false);
    final successorIdentity = _ready(
      participantId: participantId,
      address: address,
      sessionId: 'app-session-b',
    );
    final retiredIdentity = _ready(
      participantId: participantId,
      address: address,
      sessionId: 'app-session-a',
    );
    IdentitySnapshots.publish(retiredIdentity);
    final retiredCapability = await _seedAccount(retiredIdentity);

    final registrationRepo = ZkPassportRegistrationRepository();
    await registrationRepo.storePendingCompletion(
      capability: retiredCapability,
      participantId: participantId,
      challengeId: challengeId,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
    );
    IdentitySnapshots.publish(successorIdentity);
    await _seedAccount(successorIdentity);

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
      await registrationRepo.getPendingCompletion(retiredCapability),
      isNotNull,
    );
  });
}
