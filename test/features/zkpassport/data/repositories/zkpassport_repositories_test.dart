import 'dart:convert';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('device-only zkPassport settings round-trip', () async {
    final repo = ZkPassportSettingsRepository();
    expect((await repo.load()).facematchStrict, isTrue);
    await repo.setFacematchStrict(false);
    expect((await repo.load()).facematchStrict, isFalse);
  });

  test('runtime session stays in its captured launch bucket', () async {
    const bucket = 'bucket-a';
    const session = ZkPassportRuntimeSession(
      requestId: 'request-a',
      facematchStrict: true,
      phase: ZkPassportPipelinePhase.waiting,
      createdAtMs: 1,
      lastProgressAtMs: 2,
      resumeAttemptCount: 0,
      requestNonce: 'nonce-a',
      launchBucket: bucket,
      launchParticipantId: 7,
    );
    final repo = ZkPassportRuntimeSessionRepository();
    NetworkPrefs.setActiveBucket(null, guest: true);

    await repo.save(session);
    expect(await repo.load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixAccountKeyFor(
      'zkpassport:runtime_session_v1',
      bucket,
    );
    expect(prefs.getString(key), isNotNull);
    await repo.clear(bucket: bucket);
    expect(prefs.getString(key), isNull);
  });

  test('pending completion keeps exact scope and terminal outcome hides it',
      () async {
    const accountId = 'account-a';
    const address = 'ut1-test-address';
    const version = ZkPassportRequestVersion(
      requestId: 'request-a',
      createdAtMs: 100,
      nonce: 'nonce-a',
    );
    final bucket = NetworkPrefs.bucketForAddress(address);
    final repo = ZkPassportRegistrationRepository();

    await repo.storePendingCompletion(
      participantId: 7,
      challengeId: 42,
      walletAddress: address,
      sessionId: version.requestId,
      nullifierHex: 'nullifier-a',
      requestVersion: version,
      accountId: accountId,
      facematchVerified: true,
      verifyOuterMs: 11,
      wrapOuterMs: 12,
      verifyWrappedMs: 13,
      bucket: bucket,
    );
    final pending = await repo.getPendingCompletion(bucket: bucket);
    expect(pending?['account_id'], accountId);
    expect(pending?['facematch_verified'], isTrue);

    await repo.recordRequestOutcome(
      version: version,
      outcome: ZkPassportRequestOutcome.rejected,
      bucket: bucket,
    );
    expect(await repo.getPendingCompletion(bucket: bucket), isNull);
  });

  test('session server keeps its exact proof request shape', () async {
    String? publicKey;
    final repo = ZkPassportSessionServerRepository(
      baseUrl: 'https://sv.example.com/',
      writesEnabled: true,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://sv.example.com/v1/zkp/sessions/start',
        );
        publicKey = request.headers['X-Usernode-Public-Key'];
        return http.Response(
          jsonEncode({
            'session_id': 'session-a',
            'status': 'started',
            'launch_url': 'https://zk.example/launch',
          }),
          200,
        );
      }),
    );

    final result = await repo.startSession(
      walletAddress: 'address-a',
      chainId: 'local',
      nonce: 1,
      facematchStrict: true,
      userPublicKey: '  public\tkey  ',
    );
    expect(result.sessionId, 'session-a');
    expect(publicKey, 'public key');
  });
}
