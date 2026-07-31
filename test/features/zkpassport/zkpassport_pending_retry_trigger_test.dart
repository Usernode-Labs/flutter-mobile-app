import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
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

  @override
  Future<bool> completeZkPassport({
    required AuthenticatedUserLease authority,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    completionCalls++;
    return true;
  }
}

class _ScopedRegistrationRepository extends ZkPassportRegistrationRepository {
  final requestedScopes = <AccountStorageScope>[];

  @override
  Future<ZkPassportLocalRegistration> getRegistrationForAccount({
    required AccountStorageScope scope,
  }) async {
    requestedScopes.add(scope);
    return ZkPassportLocalRegistration(
      registered: scope.accountId == 'account-a',
      nullifierHex: scope.accountId == 'account-a' ? 'nullifier-a' : null,
      registeredAtMs: scope.accountId == 'account-a' ? 100 : null,
    );
  }
}

Future<void> _pumpUntil(bool Function() condition) async {
  for (var i = 0; i < 40 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  tearDown(IdentitySnapshots.reset);

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
    final scope = ZkIdentityScope(
      network: NetworkPrefs.currentNetwork,
      bucket: bucket,
      participantId: participantId,
      accountId: accountId,
      address: address,
      challengeId: challengeId,
    );
    NetworkPrefs.setActiveBucket(address, guest: false);
    IdentitySnapshots.publish(const Identity(
      epoch: 3,
      phase: IdentityPhase.ready,
      participantId: participantId,
      accountId: accountId,
      address: address,
    ));

    final registrationRepo = ZkPassportRegistrationRepository();
    await registrationRepo.storePendingCompletion(
      scope: scope,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
    );

    final activeChallengeId = StateProvider<int?>((_) => null);
    final api = _RecordingLeaderboardApiService();
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWithValue(
        IdentitySnapshots.current,
      ),
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
      await registrationRepo.getPendingCompletion(scope: scope),
      isNotNull,
    );

    container.read(activeChallengeId.notifier).state = challengeId;
    await _pumpUntil(() => api.completionCalls == 1);

    expect(api.completionCalls, 1);
    expect(
      await registrationRepo.getPendingCompletion(scope: scope),
      isNull,
    );
  });

  test('registration providers follow the current explicit account scope',
      () async {
    const identityA = Identity(
      epoch: 3,
      phase: IdentityPhase.ready,
      participantId: 7,
      accountId: 'account-a',
      address: 'ut1-account-a',
    );
    const identityB = Identity(
      epoch: 4,
      phase: IdentityPhase.ready,
      participantId: 8,
      accountId: 'account-b',
      address: 'ut1-account-b',
    );
    final currentIdentity = StateProvider<Identity>((_) => identityA);
    final repo = _ScopedRegistrationRepository();
    final container = ProviderContainer(overrides: [
      zkPassportCurrentIdentityProvider.overrideWith(
        (ref) => ref.watch(currentIdentity),
      ),
      zkPassportRegistrationRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(zkPassportIsRegisteredProvider.future), isTrue);
    expect(
      (await container.read(zkPassportRegistrationProvider.future))
          .nullifierHex,
      'nullifier-a',
    );

    container.read(currentIdentity.notifier).state = identityB;

    expect(
      await container.read(zkPassportIsRegisteredProvider.future),
      isFalse,
    );
    expect(
      (await container.read(zkPassportRegistrationProvider.future)).registered,
      isFalse,
    );
    expect(repo.requestedScopes.map((scope) => scope.accountId), [
      'account-a',
      'account-b',
    ]);
  });
}
