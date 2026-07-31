import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(
        {NetworkPrefs.networkKey: 'testnet'});
    await NetworkPrefs.getNetwork();
  });

  group('ZkPassportSettingsRepository', () {
    final repo = ZkPassportSettingsRepository();
    const scope = AccountStorageScope(
      network: 'testnet',
      bucket: 'bucket-settings',
      accountId: 'account-settings',
      address: 'ut1-settings',
    );

    test('load returns defaults when nothing stored', () async {
      final s = await repo.load(scope: scope);
      expect(s.facematchStrict, ZkPassportSettings.defaults.facematchStrict);
    });

    test('save then load round-trips', () async {
      await repo.save(
        scope: scope,
        settings: const ZkPassportSettings(facematchStrict: false),
      );
      expect((await repo.load(scope: scope)).facematchStrict, isFalse);
    });

    test('setFacematchStrict updates the stored value', () async {
      await repo.setFacematchStrict(scope: scope, value: false);
      expect((await repo.load(scope: scope)).facematchStrict, isFalse);
      await repo.setFacematchStrict(scope: scope, value: true);
      expect((await repo.load(scope: scope)).facematchStrict, isTrue);
    });

    test('explicit settings scope ignores ambient network and bucket changes',
        () async {
      await repo.save(
        scope: scope,
        settings: const ZkPassportSettings(facematchStrict: false),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NetworkPrefs.networkKey, 'internal');
      await NetworkPrefs.getNetwork();
      NetworkPrefs.setActiveBucket('ut1-other', guest: false);

      expect((await repo.load(scope: scope)).facematchStrict, isFalse);
      await repo.setFacematchStrict(scope: scope, value: true);
      expect((await repo.load(scope: scope)).facematchStrict, isTrue);
    });
  });

  group('ZkPassportRuntimeSessionRepository', () {
    final repo = ZkPassportRuntimeSessionRepository();
    const scope = ZkIdentityScope(
      network: 'testnet',
      bucket: 'bucket-a',
      participantId: 7,
      accountId: 'account-a',
      address: 'ut1-account-a',
      challengeId: 42,
    );

    ZkPassportRuntimeSession session() => const ZkPassportRuntimeSession(
          requestId: 'req',
          facematchStrict: true,
          phase: ZkPassportPipelinePhase.waiting,
          createdAtMs: 1,
          lastProgressAtMs: 2,
          resumeAttemptCount: 0,
          requestNonce: 'nonce-a',
          launchScope: scope,
        );

    test('load null when empty', () async {
      expect(await repo.load(scope: scope), isNull);
    });

    test('save/load round-trip and clear', () async {
      await repo.save(session());
      final loaded = await repo.load(scope: scope);
      expect(loaded, isNotNull);
      expect(loaded!.requestId, 'req');
      expect(loaded.requestVersion, session().requestVersion);

      await repo.clear(scope: scope);
      expect(await repo.load(scope: scope), isNull);
    });

    test('corrupt json resolves to null (and is cleared)', () async {
      final repo2 = ZkPassportRuntimeSessionRepository();
      await repo2.save(session());
      // Overwrite the stored value with junk by saving a bad string directly.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Any key: load() reads a specific prefixed key which is now absent.
      expect(prefs.getKeys().isEmpty, isTrue);
      expect(await repo2.load(scope: scope), isNull);
    });

    test('explicit scope ignores ambient network and bucket changes', () async {
      await repo.save(session());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NetworkPrefs.networkKey, 'internal');
      await NetworkPrefs.getNetwork();
      NetworkPrefs.setActiveBucket('ut1-other', guest: false);

      expect((await repo.load(scope: scope))?.requestId, 'req');
      await repo.clear(scope: scope);
      expect(await repo.load(scope: scope), isNull);
    });

    test('a different challenge can inspect and retire the account runtime',
        () async {
      const otherChallenge = ZkIdentityScope(
        network: 'testnet',
        bucket: 'bucket-a',
        participantId: 7,
        accountId: 'account-a',
        address: 'ut1-account-a',
        challengeId: 43,
      );
      await repo.save(session());

      final loaded = await repo.load(scope: otherChallenge);
      expect(loaded?.launchScope, scope);
      expect(
        await repo.clearIfCurrent(
          scope: scope,
          requestKey: session().requestVersion!.key,
        ),
        isTrue,
      );
      expect(await repo.load(scope: scope), isNull);
    });

    test('compare-and-clear preserves a replacement request', () async {
      await repo.save(session());
      const replacement = ZkPassportRuntimeSession(
        requestId: 'req',
        facematchStrict: true,
        phase: ZkPassportPipelinePhase.waiting,
        createdAtMs: 3,
        lastProgressAtMs: 4,
        resumeAttemptCount: 0,
        requestNonce: 'nonce-b',
        launchScope: scope,
      );
      await repo.save(replacement);

      expect(
        await repo.clearIfCurrent(
          scope: scope,
          requestKey: session().requestVersion!.key,
        ),
        isFalse,
      );
      expect(
        (await repo.load(scope: scope))?.requestVersion,
        replacement.requestVersion,
      );
    });

    test('failed runtime removals are surfaced and preserve recovery state',
        () async {
      final failingRepo = ZkPassportRuntimeSessionRepository(
        keyRemover: (_, __) async => false,
      );
      await failingRepo.save(session());

      expect(
        await failingRepo.clearIfCurrent(
          scope: scope,
          requestKey: session().requestVersion!.key,
        ),
        isFalse,
      );
      expect(await failingRepo.load(scope: scope), isNotNull);
      await expectLater(
        failingRepo.clear(scope: scope),
        throwsStateError,
      );
      expect(await failingRepo.load(scope: scope), isNotNull);
    });
  });

  group('ZkPassportRegistrationRepository request outcomes', () {
    const accountId = 'account-a';
    const address = 'ut1-test-address';
    late String bucket;
    late ZkPassportRegistrationRepository repo;

    ZkIdentityScope scope({int challengeId = 42}) => ZkIdentityScope(
          network: 'testnet',
          bucket: bucket,
          participantId: 7,
          accountId: accountId,
          address: address,
          challengeId: challengeId,
        );

    AccountStorageScope accountScope() => AccountStorageScope(
          network: 'testnet',
          bucket: bucket,
          accountId: accountId,
          address: address,
        );

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
        scope: scope(),
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier-${requestVersion.nonce}',
        requestVersion: requestVersion,
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
        scope: scope(),
      );

      expect(await repo.getPendingCompletion(scope: scope()), isNull);
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
        scope: scope(),
      );

      final newVersion = version('nonce-new');
      await storeOptimisticState(newVersion);

      expect(
        ZkPassportRequestVersion.fromJson(
          await repo.getPendingCompletion(scope: scope()),
        ),
        newVersion,
      );
      expect((await repo.getActiveRegistration()).registered, isTrue);
      expect(
        (await repo.getActiveRegistration()).requestVersion,
        newVersion,
      );
    });

    test('an unresolved outbox cannot be overwritten by another generation',
        () async {
      final first = version('nonce-first');
      final replacement = version('nonce-replacement');
      await repo.storePendingCompletion(
        scope: scope(),
        sessionId: first.requestId,
        nullifierHex: 'first-nullifier',
        requestVersion: first,
      );

      await expectLater(
        repo.storePendingCompletion(
          scope: scope(),
          sessionId: replacement.requestId,
          nullifierHex: 'replacement-nullifier',
          requestVersion: replacement,
        ),
        throwsStateError,
      );
      expect(
        ZkPassportRequestVersion.fromJson(
          await repo.getPendingCompletion(scope: scope()),
        ),
        first,
      );
    });

    test('delivered outcome retires outbox but preserves registration',
        () async {
      final delivered = version('nonce-delivered');
      await storeOptimisticState(delivered);
      await repo.recordRequestOutcome(
        version: delivered,
        outcome: ZkPassportRequestOutcome.delivered,
        scope: scope(),
      );

      expect(await repo.getPendingCompletion(scope: scope()), isNull);
      expect((await repo.getActiveRegistration()).registered, isTrue);
      await repo.recordRequestOutcome(
        version: delivered,
        outcome: ZkPassportRequestOutcome.rejected,
        scope: scope(),
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
          scope: scope(),
        ),
        second.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.delivered,
          scope: scope(),
        ),
      ]);

      expect(await repo.getPendingCompletion(scope: scope()), isNull);
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
        scope: scope(),
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
        facematchVerified: true,
        verifyOuterMs: 11,
        wrapOuterMs: 12,
        verifyWrappedMs: 13,
      );

      final pending = await repo.getPendingCompletion(scope: scope());
      expect(pending, isNotNull);
      expect(ZkIdentityScope.fromJson(pending!['scope']), scope());
      expect(pending, isNot(contains('account_id')));
      expect(pending['facematch_verified'], isTrue);
      expect(pending['verify_outer_ms'], 11);
      expect(pending['wrap_outer_ms'], 12);
      expect(pending['verify_wrapped_ms'], 13);
      expect(
        ZkIdentityScope.fromJson((await repo.getPendingCompletion(
          scope: scope(challengeId: 43),
        ))!['scope'])
            ?.challengeId,
        42,
      );
    });

    test('explicit registration writes ignore changed ambient storage',
        () async {
      final requestVersion = version('nonce-explicit-scope');
      NetworkPrefs.setActiveBucket('ut1-other-address', guest: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NetworkPrefs.networkKey, 'internal');
      await NetworkPrefs.getNetwork();

      await repo.storeRegistrationForAccount(
        scope: accountScope(),
        registered: true,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
      );

      final stored = await repo.getRegistrationForAccount(
        scope: accountScope(),
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
          scope: scope(),
          sessionId: requestVersion.requestId,
          nullifierHex: 'nullifier',
          requestVersion: requestVersion,
        ),
        throwsStateError,
      );
      await expectLater(
        failingRepo.recordRequestOutcome(
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
          scope: scope(),
        ),
        throwsStateError,
      );
    });

    test('failed exact outbox removal is reported and preserves the row',
        () async {
      final failingRepo = ZkPassportRegistrationRepository(
        keyRemover: (_, __) async => false,
      );
      final requestVersion = version('nonce-remove-failure');
      await failingRepo.storePendingCompletion(
        scope: scope(),
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
      );

      expect(
        await failingRepo.clearPendingCompletionIfCurrent(
          scope: scope(),
          sessionId: requestVersion.requestId,
        ),
        isFalse,
      );
      expect(
        await failingRepo.getPendingCompletion(scope: scope()),
        isNotNull,
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
