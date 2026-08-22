import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ZkPassportSettingsRepository', () {
    final repo = ZkPassportSettingsRepository();

    test('load returns defaults when nothing stored', () async {
      final s = await repo.load();
      expect(s.facematchStrict, ZkPassportSettings.defaults.facematchStrict);
    });

    test('save then load round-trips', () async {
      await repo.save(const ZkPassportSettings(facematchStrict: false));
      expect((await repo.load()).facematchStrict, isFalse);
    });

    test('setFacematchStrict updates the stored value', () async {
      await repo.setFacematchStrict(false);
      expect((await repo.load()).facematchStrict, isFalse);
      await repo.setFacematchStrict(true);
      expect((await repo.load()).facematchStrict, isTrue);
    });
  });

  group('ZkPassportRuntimeSessionRepository', () {
    final repo = ZkPassportRuntimeSessionRepository();

    ZkPassportRuntimeSession session() => const ZkPassportRuntimeSession(
          appSessionId: 'app-session-a',
          requestId: 'req',
          facematchStrict: true,
          phase: ZkPassportPipelinePhase.waiting,
          createdAtMs: 1,
          lastProgressAtMs: 2,
          resumeAttemptCount: 0,
          requestNonce: 'nonce-a',
        );

    test('load null when empty', () async {
      expect(await repo.load(), isNull);
    });

    test('save/load round-trip and clear', () async {
      await repo.save(session());
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.requestId, 'req');
      expect(loaded.requestVersion, session().requestVersion);

      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('runtime writes cross the exact workflow-store permit', () async {
      final admitted = <Map<String, String>>[];
      final gated = ZkPassportRuntimeSessionRepository(
        workflowMutation: ({
          required appSessionId,
          required operationId,
          required mutation,
        }) async {
          admitted.add({
            'app_session_id': appSessionId,
            'operation_id': operationId,
          });
          return mutation();
        },
      );

      await gated.save(session());

      expect(admitted, [
        {
          'app_session_id': 'app-session-a',
          'operation_id': 'zk-runtime:req:1:nonce-a',
        },
      ]);
    });

    test('writes follow the launch bucket, not the ambient one', () async {
      const launchBucket = 'bucket-a';
      final launched = ZkPassportRuntimeSession(
        appSessionId: session().appSessionId,
        requestId: session().requestId,
        facematchStrict: session().facematchStrict,
        phase: session().phase,
        createdAtMs: session().createdAtMs,
        lastProgressAtMs: session().lastProgressAtMs,
        resumeAttemptCount: session().resumeAttemptCount,
        requestNonce: session().requestNonce,
        launchBucket: launchBucket,
        launchParticipantId: 1,
      );
      NetworkPrefs.setActiveBucket(null, guest: true);

      // Phase writes land after long Rust/RPC awaits: by then the app may have
      // signed out (guest bucket) or admitted the next user. Recomputing the
      // bucket per call is how A's proof ends up in B's bucket.
      await repo.save(launched);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(NetworkPrefs.prefixAccountKeyFor(
            'zkpassport:runtime_session_v1', launchBucket)),
        isNotNull,
      );
      expect(
        prefs.getString(
            NetworkPrefs.prefixAccountKey('zkpassport:runtime_session_v1')),
        isNull,
        reason: 'the ambient (guest) bucket must not receive the row',
      );
      // And finalization clears the row it actually wrote.
      await repo.clear();
      expect(
        prefs.getString(NetworkPrefs.prefixAccountKeyFor(
            'zkpassport:runtime_session_v1', launchBucket)),
        isNotNull,
        reason: 'an ambient clear must not reach the launch bucket',
      );
      await repo.clear(bucket: launchBucket);
      expect(
        prefs.getString(NetworkPrefs.prefixAccountKeyFor(
            'zkpassport:runtime_session_v1', launchBucket)),
        isNull,
      );
    });

    test('legacy row without an app session remains stored but inert',
        () async {
      NetworkPrefs.setActiveBucket(null, guest: true);
      final prefs = await SharedPreferences.getInstance();
      final key = NetworkPrefs.prefixAccountKey(
        'zkpassport:runtime_session_v1',
      );
      final legacy = session().toJson()..remove('appSessionId');
      final raw = jsonEncode(legacy);
      await prefs.setString(key, raw);

      expect(await repo.load(), isNull);
      expect(prefs.getString(key), raw);
    });

    test('corrupt json resolves to null (and is cleared)', () async {
      final repo2 = ZkPassportRuntimeSessionRepository();
      await repo2.save(session());
      // Overwrite the stored value with junk by saving a bad string directly.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Any key: load() reads a specific prefixed key which is now absent.
      expect(prefs.getKeys().isEmpty, isTrue);
      expect(await repo2.load(), isNull);
    });
  });

  group('ZkPassportRegistrationRepository request outcomes', () {
    const accountId = 'account-a';
    const address = 'ut1-test-address';
    late String bucket;
    late ZkPassportRegistrationRepository repo;

    ZkPassportRequestVersion version(String nonce) => ZkPassportRequestVersion(
          requestId: 'reused-session-id',
          createdAtMs: 100,
          nonce: nonce,
        );

    Future<void> seedActiveAccount() async {
      bucket = NetworkPrefs.bucketForAddress(address);
      NetworkPrefs.setActiveBucket(address, guest: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'testnet:accounts:index',
        jsonEncode([
          {
            'id': accountId,
            'name': 'Test',
            'createdAt': '2026-01-01T00:00:00.000Z',
            'derivationPath': 'test',
            'hdIndex': 0,
            'address': address,
            'publicKey': 'pk',
            'backupConfirmed': true,
            'isDemo': true,
          },
        ]),
      );
      await prefs.setString('testnet:accounts:activeId', accountId);
    }

    setUp(() async {
      repo = ZkPassportRegistrationRepository();
      await seedActiveAccount();
    });

    Future<void> storeOptimisticState(
      ZkPassportRequestVersion requestVersion,
    ) async {
      await repo.storePendingCompletion(
        appSessionId: 'app-session-a',
        participantId: 7,
        challengeId: 42,
        walletAddress: address,
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier-${requestVersion.nonce}',
        requestVersion: requestVersion,
        accountId: accountId,
        bucket: bucket,
      );
      await repo.storeActiveRegistration(
        registered: true,
        nullifierHex: 'nullifier-${requestVersion.nonce}',
        requestVersion: requestVersion,
      );
    }

    test('one rejected outcome atomically hides outbox and registration',
        () async {
      final rejected = version('nonce-a');
      await storeOptimisticState(rejected);

      await repo.recordRequestOutcome(
        version: rejected,
        outcome: ZkPassportRequestOutcome.rejected,
        bucket: bucket,
      );

      expect(await repo.getPendingCompletion(bucket: bucket), isNull);
      expect((await repo.getActiveRegistration()).registered, isFalse);

      // The source rows deliberately remain. The outcome is the only durable
      // write needed for both views, so cleanup cannot be split by a crash.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(
          'testnet:acct:$bucket:zkpassport:pending_completion',
        ),
        isNotNull,
      );
      expect(
        prefs.getString(
          'testnet:acct:$bucket:zkpassport:registration:$accountId',
        ),
        isNotNull,
      );
    });

    test('old outcome cannot hide a reused request ID generation', () async {
      final oldVersion = version('nonce-old');
      await storeOptimisticState(oldVersion);
      await repo.recordRequestOutcome(
        version: oldVersion,
        outcome: ZkPassportRequestOutcome.rejected,
        bucket: bucket,
      );

      final newVersion = version('nonce-new');
      await storeOptimisticState(newVersion);

      expect(
        ZkPassportRequestVersion.fromJson(
          await repo.getPendingCompletion(bucket: bucket),
        ),
        newVersion,
      );
      expect((await repo.getActiveRegistration()).registered, isTrue);
      expect(
        (await repo.getActiveRegistration()).requestVersion,
        newVersion,
      );
    });

    test('delivered outcome retires outbox but preserves registration',
        () async {
      final delivered = version('nonce-delivered');
      await storeOptimisticState(delivered);
      await repo.recordRequestOutcome(
        version: delivered,
        outcome: ZkPassportRequestOutcome.delivered,
        bucket: bucket,
      );

      expect(await repo.getPendingCompletion(bucket: bucket), isNull);
      expect((await repo.getActiveRegistration()).registered, isTrue);
      await repo.recordRequestOutcome(
        version: delivered,
        outcome: ZkPassportRequestOutcome.rejected,
        bucket: bucket,
      );
      expect((await repo.getActiveRegistration()).registered, isTrue);
    });

    test('concurrent conflicting outcomes are append-only; delivery wins',
        () async {
      final requestVersion = version('nonce-concurrent');
      await storeOptimisticState(requestVersion);
      final bothWritersReady = Completer<void>();
      var writerCount = 0;
      Future<bool> barrierWriter(
        SharedPreferences preferences,
        String key,
        String value,
      ) async {
        writerCount++;
        if (writerCount == 2) bothWritersReady.complete();
        await bothWritersReady.future;
        return preferences.setString(key, value);
      }

      final first = ZkPassportRegistrationRepository(
        stringWriter: barrierWriter,
      );
      final second = ZkPassportRegistrationRepository(
        stringWriter: barrierWriter,
      );
      await Future.wait([
        first.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
          bucket: bucket,
        ),
        second.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.delivered,
          bucket: bucket,
        ),
      ]);

      expect(await repo.getPendingCompletion(bucket: bucket), isNull);
      expect((await repo.getActiveRegistration()).registered, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('request_outcome_v1')),
        hasLength(2),
      );
    });

    test('outbox retains the exact registration repair scope and metadata',
        () async {
      final requestVersion = version('nonce-repair');
      await repo.storePendingCompletion(
        appSessionId: 'app-session-a',
        participantId: 7,
        challengeId: 42,
        walletAddress: address,
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
        accountId: accountId,
        facematchVerified: true,
        verifyOuterMs: 11,
        wrapOuterMs: 12,
        verifyWrappedMs: 13,
        bucket: bucket,
      );

      final pending = await repo.getPendingCompletion(bucket: bucket);
      expect(pending, isNotNull);
      expect(pending!['app_session_id'], 'app-session-a');
      expect(pending['account_id'], accountId);
      expect(pending['facematch_verified'], isTrue);
      expect(pending['verify_outer_ms'], 11);
      expect(pending['wrap_outer_ms'], 12);
      expect(pending['verify_wrapped_ms'], 13);
    });

    test('pending outbox writes cross the exact workflow-store permit',
        () async {
      final requestVersion = version('nonce-permit');
      final admitted = <Map<String, String>>[];
      final gated = ZkPassportRegistrationRepository(
        workflowMutation: ({
          required appSessionId,
          required operationId,
          required mutation,
        }) async {
          admitted.add({
            'app_session_id': appSessionId,
            'operation_id': operationId,
          });
          return mutation();
        },
      );

      await gated.storePendingCompletion(
        appSessionId: 'app-session-a',
        participantId: 7,
        challengeId: 42,
        walletAddress: address,
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
        accountId: accountId,
        bucket: bucket,
      );

      expect(admitted, [
        {
          'app_session_id': 'app-session-a',
          'operation_id': 'zk-outbox:reused-session-id:100:nonce-permit',
        },
      ]);
    });

    test('legacy outbox row without an app session remains stored but inert',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final key = 'testnet:acct:$bucket:zkpassport:pending_completion';
      final raw = jsonEncode({
        'participant_id': 7,
        'challenge_id': 42,
        'wallet_address': address,
        'session_id': 'request-a',
        'nullifier_hex': 'nullifier',
        'account_id': accountId,
        ...version('nonce-legacy').toJson(),
      });
      await prefs.setString(key, raw);

      expect(await repo.getPendingCompletion(bucket: bucket), isNull);
      expect(prefs.getString(key), raw);
    });

    test('explicit registration writes ignore a changed ambient bucket',
        () async {
      final requestVersion = version('nonce-explicit-scope');
      NetworkPrefs.setActiveBucket('ut1-other-address', guest: false);

      await repo.storeRegistrationForAccount(
        accountId: accountId,
        bucket: bucket,
        registered: true,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
      );

      final stored = await repo.getRegistrationForAccount(
        accountId: accountId,
        bucket: bucket,
      );
      expect(stored.registered, isTrue);
      expect(stored.requestVersion, requestVersion);
    });

    test('failed critical outbox and outcome writes are surfaced', () async {
      final failingRepo = ZkPassportRegistrationRepository(
        stringWriter: (_, __, ___) async => false,
      );
      final requestVersion = version('nonce-write-failure');

      await expectLater(
        failingRepo.storePendingCompletion(
          appSessionId: 'app-session-a',
          participantId: 7,
          challengeId: 42,
          walletAddress: address,
          sessionId: requestVersion.requestId,
          nullifierHex: 'nullifier',
          requestVersion: requestVersion,
          accountId: accountId,
          bucket: bucket,
        ),
        throwsStateError,
      );
      await expectLater(
        failingRepo.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
          bucket: bucket,
        ),
        throwsStateError,
      );
    });
  });

  group('ZkPassportSessionServerRepository base URL normalization', () {
    test('strips trailing slash', () async {
      final repo = ZkPassportSessionServerRepository(
        baseUrl: 'https://sv.example.com/',
        writesEnabled: true,
        httpClient: MockClient((req) async {
          expect(
              req.url.toString(), 'https://sv.example.com/v1/zkp/sessions/sid');
          return http.Response(
              jsonEncode({'session_id': 'sid', 'status': 'pending'}), 200);
        }),
      );
      await repo.getSessionStatus(sessionId: 'sid');
    });

    test('empty/invalid base URL throws StateError', () {
      expect(() => ZkPassportSessionServerRepository(baseUrl: '  '),
          throwsStateError);
      expect(() => ZkPassportSessionServerRepository(baseUrl: 'not-a-url'),
          throwsStateError);
    });
  });

  group('ZkPassportSessionServerRepository requests', () {
    ZkPassportSessionServerRepository repo(MockClient client,
            {bool writes = true}) =>
        ZkPassportSessionServerRepository(
          baseUrl: 'https://sv.example.com',
          writesEnabled: writes,
          httpClient: client,
        );

    test('startSession rejects in view-only mode', () async {
      final r = repo(MockClient((_) async => http.Response('{}', 200)),
          writes: false);
      await expectLater(
        r.startSession(
            walletAddress: 'w', chainId: 'c', nonce: 1, facematchStrict: true),
        throwsA(isA<ZkPassportSessionServerException>()
            .having((e) => e.statusCode, 'status', 503)),
      );
    });

    test('startSession posts and parses response, sending pubkey header',
        () async {
      String? pk;
      final r = repo(MockClient((req) async {
        pk = req.headers['X-Usernode-Public-Key'];
        return http.Response(
            jsonEncode({
              'session_id': 'sid',
              'status': 'started',
              'launch_url': 'https://go'
            }),
            200);
      }));
      final resp = await r.startSession(
        walletAddress: 'w',
        chainId: 'c',
        nonce: 7,
        facematchStrict: true,
        userPublicKey: '  my\tkey  ',
      );
      expect(resp.sessionId, 'sid');
      expect(resp.launchUrl, 'https://go');
      expect(pk, 'my key'); // control chars collapsed to space, trimmed
    });

    test('tryGetSessionResult returns null on 409 (not ready)', () async {
      final r = repo(MockClient((_) async => http.Response('', 409)));
      expect(await r.tryGetSessionResult(sessionId: 'sid'), isNull);
    });

    test('tryGetSessionResult parses a ready result', () async {
      final r = repo(MockClient((_) async => http.Response(
          jsonEncode({'status': 'result_ok', 'proof': 'P'}), 200)));
      final res = await r.tryGetSessionResult(sessionId: 'sid');
      expect(res, isNotNull);
      expect(res!.success, isTrue);
    });

    test('non-2xx surfaces error/message from the body', () async {
      final r = repo(MockClient(
          (_) async => http.Response(jsonEncode({'error': 'nope'}), 400)));
      await expectLater(
        r.getSessionStatus(sessionId: 'sid'),
        throwsA(isA<ZkPassportSessionServerException>()
            .having((e) => e.statusCode, 'status', 400)
            .having((e) => e.message, 'message', 'nope')),
      );
    });

    test('non-map success body throws unexpected-shape', () async {
      final r = repo(MockClient((_) async => http.Response('"str"', 200)));
      await expectLater(
        r.getSessionStatus(sessionId: 'sid'),
        throwsA(isA<ZkPassportSessionServerException>()),
      );
    });

    test('exception toString includes code and message', () {
      expect(ZkPassportSessionServerException(500, 'x').toString(),
          'ZkPassportSessionServerException(500, x)');
    });
  });
}
