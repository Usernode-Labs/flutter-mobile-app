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

  @override
  Future<bool> completeZkPassport({
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
    expect(
      await registrationRepo.getPendingCompletion(bucket: bucket),
      isNull,
    );
  });
}
