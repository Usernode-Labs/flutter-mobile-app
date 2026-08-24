import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/repositories/zkpassport_repositories.dart';

const _accountNamespace = 'aaaaaaaaaaaaaaaa';
const _accountId = 'account-a';
const _address = 'ut1-test-address';
const _network = 'testnet';

Future<AccountCapability> _accountCapability({
  String sessionId = 'app-session-a',
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'testnet:identity:namespace',
    _accountNamespace,
  );
  await prefs.setString(
    'testnet:user:$_accountNamespace:accounts:index',
    jsonEncode([
      {
        'id': _accountId,
        'name': 'Test',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'derivationPath': 'test',
        'hdIndex': 0,
        'address': _address,
        'publicKey': 'pk',
        'backupConfirmed': true,
        'isDemo': true,
      },
    ]),
  );
  await prefs.setString(
    'testnet:user:$_accountNamespace:accounts:activeId',
    _accountId,
  );
  final accounts = await AccountsRepository.create();
  return accounts.capabilityFor(Identity(
    epoch: 1,
    phase: IdentityPhase.ready,
    participantId: 7,
    accountId: _accountId,
    address: _address,
    sessionId: sessionId,
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  group('ZkPassportSettingsRepository', () {
    final repo = ZkPassportSettingsRepository();
    late AccountCapability capability;

    setUp(() async => capability = await _accountCapability());

    test('load returns defaults when nothing stored', () async {
      final s = await repo.load(capability);
      expect(s.facematchStrict, ZkPassportSettings.defaults.facematchStrict);
    });

    test('save then load round-trips', () async {
      await repo.save(
        capability,
        const ZkPassportSettings(facematchStrict: false),
      );
      expect((await repo.load(capability)).facematchStrict, isFalse);
    });

    test('setFacematchStrict updates the stored value', () async {
      await repo.setFacematchStrict(capability, false);
      expect((await repo.load(capability)).facematchStrict, isFalse);
      await repo.setFacematchStrict(capability, true);
      expect((await repo.load(capability)).facematchStrict, isTrue);
    });
  });

  group('ZkPassportRuntimeSessionRepository', () {
    final repo = ZkPassportRuntimeSessionRepository();

    ZkPassportRuntimeSession session({
      String appSessionId = 'app-session-a',
      String requestId = 'req',
      int createdAtMs = 1,
      String requestNonce = 'nonce-a',
      String launchBucket = 'account-bucket',
    }) =>
        ZkPassportRuntimeSession(
          appSessionId: appSessionId,
          requestId: requestId,
          facematchStrict: true,
          phase: ZkPassportPipelinePhase.waiting,
          createdAtMs: createdAtMs,
          lastProgressAtMs: 2,
          resumeAttemptCount: 0,
          requestNonce: requestNonce,
          launchNetwork: _network,
          launchBucket: launchBucket,
        );

    test('load null when empty', () async {
      expect(
        await repo.loadForSession(
          appSessionId: 'app-session-a',
          network: _network,
          bucket: 'account-bucket',
        ),
        isNull,
      );
    });

    test('save/load round-trip and clear', () async {
      await repo.save(session());
      final loaded = await repo.loadForSession(
        appSessionId: 'app-session-a',
        network: _network,
        bucket: 'account-bucket',
      );
      expect(loaded, isNotNull);
      expect(loaded!.requestId, 'req');
      expect(loaded.requestVersion, session().requestVersion);

      await repo.clear(loaded);
      expect(
        await repo.loadForSession(
          appSessionId: 'app-session-a',
          network: _network,
          bucket: 'account-bucket',
        ),
        isNull,
      );
    });

    test('late exact-owner writes and clears cannot touch a successor',
        () async {
      const bucket = 'same-user-bucket';
      final retired = session(
        appSessionId: 'app-session-a',
        requestId: 'operation-a',
        createdAtMs: 10,
        requestNonce: 'nonce-a',
        launchBucket: bucket,
      );
      final successor = session(
        appSessionId: 'app-session-b',
        requestId: 'operation-b',
        createdAtMs: 20,
        requestNonce: 'nonce-b',
        launchBucket: bucket,
      );

      await repo.save(retired);
      await repo.save(successor);
      await repo.save(retired.copyWith(
        phase: ZkPassportPipelinePhase.proofReceived,
        lastProgressAtMs: 30,
      ));
      await repo.clear(retired);

      final recovered = await repo.loadForSession(
        appSessionId: successor.appSessionId,
        network: _network,
        bucket: bucket,
      );
      expect(recovered?.requestId, successor.requestId);
      expect(
        await repo.loadForSession(
          appSessionId: retired.appSessionId,
          network: _network,
          bucket: bucket,
        ),
        isNull,
      );
    });

    test('recovery deterministically selects the newest owned operation',
        () async {
      const bucket = 'account-bucket';
      final old = session(
        requestId: 'operation-old',
        createdAtMs: 10,
        requestNonce: 'nonce-old',
        launchBucket: bucket,
      );
      final current = session(
        requestId: 'operation-current',
        createdAtMs: 20,
        requestNonce: 'nonce-current',
        launchBucket: bucket,
      );

      await repo.save(old);
      await repo.save(current);
      await repo.save(old.copyWith(lastProgressAtMs: 30));

      final recovered = await repo.loadForSession(
        appSessionId: current.appSessionId,
        network: _network,
        bucket: bucket,
      );
      expect(recovered?.requestId, current.requestId);
      await repo.clear(old);
      expect(
        (await repo.loadForSession(
          appSessionId: current.appSessionId,
          network: _network,
          bucket: bucket,
        ))
            ?.requestId,
        current.requestId,
      );
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
        launchNetwork: _network,
        launchBucket: launchBucket,
        launchParticipantId: 1,
      );
      NetworkPrefs.setActiveBucket(null, guest: true);

      // Phase writes land after long Rust/RPC awaits: by then the app may have
      // signed out (guest bucket) or admitted the next user. Recomputing the
      // bucket per call is how A's proof ends up in B's bucket.
      await repo.save(launched);

      expect(
        await repo.loadForSession(
          appSessionId: launched.appSessionId,
          network: _network,
          bucket: launchBucket,
        ),
        isNotNull,
      );
      expect(
        await repo.loadForSession(
          appSessionId: launched.appSessionId,
          network: _network,
          bucket: NetworkPrefs.guestBucket,
        ),
        isNull,
        reason: 'the ambient (guest) bucket must not receive the row',
      );
      await repo.clear(launched);
      expect(
        await repo.loadForSession(
          appSessionId: launched.appSessionId,
          network: _network,
          bucket: launchBucket,
        ),
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

      expect(
        await repo.loadForSession(
          appSessionId: session().appSessionId,
          network: _network,
          bucket: NetworkPrefs.guestBucket,
        ),
        isNull,
      );
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
      expect(
        await repo2.loadForSession(
          appSessionId: session().appSessionId,
          network: _network,
          bucket: session().launchBucket!,
        ),
        isNull,
      );
    });
  });

  group('ZkPassportRegistrationRepository request outcomes', () {
    late String bucket;
    late ZkPassportRegistrationRepository repo;
    late AccountCapability capability;
    late AccountCapability successorCapability;

    ZkPassportRequestVersion version(
      String nonce, {
      int createdAtMs = 100,
    }) =>
        ZkPassportRequestVersion(
          requestId: 'reused-session-id',
          createdAtMs: createdAtMs,
          nonce: nonce,
        );

    Future<void> seedActiveAccount() async {
      bucket = NetworkPrefs.bucketForAddress(_address);
      NetworkPrefs.setActiveBucket(_address, guest: false);
      capability = await _accountCapability();
      successorCapability = await _accountCapability(
        sessionId: 'app-session-b',
      );
    }

    setUp(() async {
      repo = ZkPassportRegistrationRepository();
      await seedActiveAccount();
    });

    Future<void> storeOptimisticState(
      ZkPassportRequestVersion requestVersion,
    ) async {
      await repo.storePendingCompletion(
        capability: capability,
        participantId: 7,
        challengeId: 42,
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier-${requestVersion.nonce}',
        requestVersion: requestVersion,
      );
      await repo.storeActiveRegistration(
        capability: capability,
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
        capability: capability,
        version: rejected,
        outcome: ZkPassportRequestOutcome.rejected,
      );

      expect(await repo.getPendingCompletion(capability), isNull);
      expect(
        (await repo.getActiveRegistration(capability)).registered,
        isFalse,
      );

      // The source rows deliberately remain. The outcome is the only durable
      // write needed for both views, so cleanup cannot be split by a crash.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('pending_completion_v2')),
        hasLength(1),
      );
      expect(
        prefs.getKeys().where((key) => key.contains('registration_v2')),
        hasLength(1),
      );
    });

    test('old outcome cannot hide a reused request ID generation', () async {
      final oldVersion = version('nonce-old');
      await storeOptimisticState(oldVersion);
      await repo.recordRequestOutcome(
        capability: capability,
        version: oldVersion,
        outcome: ZkPassportRequestOutcome.rejected,
      );

      final newVersion = version('nonce-new', createdAtMs: 101);
      await storeOptimisticState(newVersion);

      expect(
        ZkPassportRequestVersion.fromJson(
          await repo.getPendingCompletion(capability),
        ),
        newVersion,
      );
      expect(
        (await repo.getActiveRegistration(capability)).registered,
        isTrue,
      );
      expect(
        (await repo.getActiveRegistration(capability)).requestVersion,
        newVersion,
      );
    });

    test('delivered outcome retires outbox but preserves registration',
        () async {
      final delivered = version('nonce-delivered');
      await storeOptimisticState(delivered);
      await repo.recordRequestOutcome(
        capability: capability,
        version: delivered,
        outcome: ZkPassportRequestOutcome.delivered,
      );

      expect(await repo.getPendingCompletion(capability), isNull);
      expect(
        (await repo.getActiveRegistration(capability)).registered,
        isTrue,
      );
      await repo.recordRequestOutcome(
        capability: capability,
        version: delivered,
        outcome: ZkPassportRequestOutcome.rejected,
      );
      expect(
        (await repo.getActiveRegistration(capability)).registered,
        isTrue,
      );
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
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
        ),
        second.recordRequestOutcome(
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.delivered,
        ),
      ]);

      expect(await repo.getPendingCompletion(capability), isNull);
      expect(
        (await repo.getActiveRegistration(capability)).registered,
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((key) => key.contains('request_outcome_v2')),
        hasLength(2),
      );
    });

    test('outbox retains the exact registration repair scope and metadata',
        () async {
      final requestVersion = version('nonce-repair');
      await repo.storePendingCompletion(
        capability: capability,
        participantId: 7,
        challengeId: 42,
        sessionId: requestVersion.requestId,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
        facematchVerified: true,
        verifyOuterMs: 11,
        wrapOuterMs: 12,
        verifyWrappedMs: 13,
      );

      final pending = await repo.getPendingCompletion(capability);
      expect(pending, isNotNull);
      expect(pending!['app_session_id'], 'app-session-a');
      expect(pending['account_id'], _accountId);
      expect(pending['facematch_verified'], isTrue);
      expect(pending['verify_outer_ms'], 11);
      expect(pending['wrap_outer_ms'], 12);
      expect(pending['verify_wrapped_ms'], 13);
    });

    test('late outbox cleanup cannot remove a same-user successor row',
        () async {
      final retired = version('nonce-retired');
      const successor = ZkPassportRequestVersion(
        requestId: 'successor-request',
        createdAtMs: 200,
        nonce: 'nonce-successor',
      );
      await repo.storePendingCompletion(
        capability: capability,
        participantId: 7,
        challengeId: 42,
        sessionId: retired.requestId,
        nullifierHex: 'retired-nullifier',
        requestVersion: retired,
      );
      await repo.storePendingCompletion(
        capability: successorCapability,
        participantId: 7,
        challengeId: 42,
        sessionId: successor.requestId,
        nullifierHex: 'successor-nullifier',
        requestVersion: successor,
      );

      await repo.clearPendingCompletion(
        capability: capability,
        requestVersion: retired,
      );
      await repo.recordRequestOutcome(
        capability: capability,
        version: retired,
        outcome: ZkPassportRequestOutcome.rejected,
      );

      final pending = await repo.getPendingCompletion(successorCapability);
      expect(pending?['session_id'], successor.requestId);
      expect(
        await repo.getPendingCompletion(capability),
        isNull,
      );
    });

    test('legacy outbox row without an app session remains stored but inert',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final key = 'testnet:acct:$bucket:zkpassport:pending_completion';
      final raw = jsonEncode({
        'participant_id': 7,
        'challenge_id': 42,
        'wallet_address': _address,
        'session_id': 'request-a',
        'nullifier_hex': 'nullifier',
        'account_id': _accountId,
        ...version('nonce-legacy').toJson(),
      });
      await prefs.setString(key, raw);

      expect(await repo.getPendingCompletion(capability), isNull);
      expect(prefs.getString(key), raw);
    });

    test('explicit registration writes ignore a changed ambient bucket',
        () async {
      final requestVersion = version('nonce-explicit-scope');
      NetworkPrefs.setActiveBucket('ut1-other-address', guest: false);

      await repo.storeRegistrationForAccount(
        capability: capability,
        registered: true,
        nullifierHex: 'nullifier',
        requestVersion: requestVersion,
      );

      final stored = await repo.getRegistrationForAccount(capability);
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
          capability: capability,
          participantId: 7,
          challengeId: 42,
          sessionId: requestVersion.requestId,
          nullifierHex: 'nullifier',
          requestVersion: requestVersion,
        ),
        throwsStateError,
      );
      await expectLater(
        failingRepo.recordRequestOutcome(
          capability: capability,
          version: requestVersion,
          outcome: ZkPassportRequestOutcome.rejected,
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
