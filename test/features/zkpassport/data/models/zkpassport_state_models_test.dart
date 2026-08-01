import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';

void main() {
  group('ZkPassportPipelineState', () {
    test('idle() has idle status/phase and empty message', () {
      final s = ZkPassportPipelineState.idle();
      expect(s.status, ZkPassportPipelineStatus.idle);
      expect(s.phase, ZkPassportPipelinePhase.idle);
      expect(s.message, '');
      expect(s.outerPublicInputsHex, isNull);
    });

    test('copyWith overrides only provided fields', () {
      final base = ZkPassportPipelineState.idle();
      final next = base.copyWith(
        status: ZkPassportPipelineStatus.processing,
        message: 'working',
        resumeAttemptCount: 2,
      );
      expect(next.status, ZkPassportPipelineStatus.processing);
      expect(next.message, 'working');
      expect(next.resumeAttemptCount, 2);
      expect(next.phase, base.phase); // untouched
      expect(base.copyWith().message, base.message);
    });
  });

  group('ZkPassportRuntimeSession', () {
    ZkPassportRuntimeSession session({
      String requestId = 'req',
      ZkPassportPipelinePhase phase = ZkPassportPipelinePhase.waiting,
      int resume = 0,
      String? pubKey,
      String? requestNonce = 'nonce-a',
    }) =>
        ZkPassportRuntimeSession(
          requestId: requestId,
          facematchStrict: true,
          phase: phase,
          createdAtMs: 100,
          lastProgressAtMs: 200,
          resumeAttemptCount: resume,
          requestNonce: requestNonce,
          userPublicKey: pubKey,
        );

    test('isTerminal only for success/failed/timedOut', () {
      expect(
          session(phase: ZkPassportPipelinePhase.success).isTerminal, isTrue);
      expect(session(phase: ZkPassportPipelinePhase.failed).isTerminal, isTrue);
      expect(
          session(phase: ZkPassportPipelinePhase.timedOut).isTerminal, isTrue);
      expect(
          session(phase: ZkPassportPipelinePhase.waiting).isTerminal, isFalse);
    });

    test('toJson omits blank userPublicKey but includes a real one', () {
      expect(
          session(pubKey: null).toJson().containsKey('userPublicKey'), isFalse);
      expect(session(pubKey: '   ').toJson().containsKey('userPublicKey'),
          isFalse);
      expect(session(pubKey: 'PK').toJson()['userPublicKey'], 'PK');
      expect(session().toJson()['phase'], 'waiting');
    });

    test('toJson -> fromJson round-trips a valid session', () {
      final original = session(requestId: 'abc', resume: 3, pubKey: 'PK');
      final parsed = ZkPassportRuntimeSession.fromJson(original.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.requestId, 'abc');
      expect(parsed.phase, ZkPassportPipelinePhase.waiting);
      expect(parsed.resumeAttemptCount, 3);
      expect(parsed.userPublicKey, 'PK');
      expect(parsed.requestVersion, original.requestVersion);
    });

    test('a reused request ID has a distinct persisted generation', () {
      final first = session(requestId: 'same', requestNonce: 'nonce-a');
      final second = session(requestId: 'same', requestNonce: 'nonce-b');

      expect(first.requestVersion, isNot(second.requestVersion));
      expect(first.requestVersion?.requestId, second.requestVersion?.requestId);
      expect(first.createdAtMs, second.createdAtMs);
    });

    test('launch identity fields persist across a round-trip', () {
      const original = ZkPassportRuntimeSession(
        requestId: 'req',
        facematchStrict: true,
        phase: ZkPassportPipelinePhase.waiting,
        createdAtMs: 100,
        lastProgressAtMs: 200,
        resumeAttemptCount: 0,
        launchEpoch: 4,
        launchBucket: 'acct_ut1abc',
        launchParticipantId: 77,
      );
      final parsed = ZkPassportRuntimeSession.fromJson(original.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.launchEpoch, 4);
      expect(parsed.launchBucket, 'acct_ut1abc');
      expect(parsed.launchParticipantId, 77);
    });

    test('legacy sessions without launch identity parse with nulls', () {
      final legacy = session().toJson()
        ..remove('launchEpoch')
        ..remove('launchBucket')
        ..remove('launchParticipantId');
      final parsed = ZkPassportRuntimeSession.fromJson(legacy);
      expect(parsed, isNotNull);
      expect(parsed!.launchEpoch, isNull);
      expect(parsed.launchBucket, isNull);
      expect(parsed.launchParticipantId, isNull);
    });

    test('fromJson rejects missing/invalid required fields', () {
      final ok = session().toJson();
      expect(ZkPassportRuntimeSession.fromJson({...ok}..remove('requestId')),
          isNull);
      expect(ZkPassportRuntimeSession.fromJson({...ok, 'phase': 'nonsense'}),
          isNull);
      expect(ZkPassportRuntimeSession.fromJson({...ok}..remove('createdAtMs')),
          isNull);
    });

    test('fromJson parses string numerics and clamps negative resume to 0', () {
      final s = ZkPassportRuntimeSession.fromJson({
        'requestId': 'r',
        'facematchStrict': true,
        'phase': 'waiting',
        'createdAtMs': '100',
        'lastProgressAtMs': '200',
        'resumeAttemptCount': -5,
      });
      expect(s, isNotNull);
      expect(s!.createdAtMs, 100);
      expect(s.resumeAttemptCount, 0);
    });

    test('copyWith overrides selected fields', () {
      final c = session().copyWith(requestId: 'new', resumeAttemptCount: 9);
      expect(c.requestId, 'new');
      expect(c.resumeAttemptCount, 9);
      expect(c.facematchStrict, isTrue);
    });
  });

  group('ZkPassportSettings', () {
    test('defaults + toJson + copyWith', () {
      expect(ZkPassportSettings.defaults.facematchStrict, isTrue);
      expect(ZkPassportSettings.defaults.toJson(), {'facematch_strict': true});
      expect(
        ZkPassportSettings.defaults
            .copyWith(facematchStrict: false)
            .facematchStrict,
        isFalse,
      );
    });

    test('fromJson reads map, rejects non-map', () {
      expect(
          ZkPassportSettings.fromJson({'facematch_strict': false})!
              .facematchStrict,
          isFalse);
      expect(ZkPassportSettings.fromJson('nope'), isNull);
    });
  });

  group('ZkPassportLocalRegistration', () {
    test('unregistered() is empty', () {
      final r = ZkPassportLocalRegistration.unregistered();
      expect(r.registered, isFalse);
      expect(r.nullifierHex, isNull);
    });

    test('toJson includes optional timing fields only when set', () {
      const bare = ZkPassportLocalRegistration(
          registered: true, nullifierHex: 'n', registeredAtMs: 5);
      expect(bare.toJson().containsKey('verify_outer_ms'), isFalse);

      const full = ZkPassportLocalRegistration(
        registered: true,
        nullifierHex: 'n',
        registeredAtMs: 5,
        facematchVerified: true,
        verifyOuterMs: 1,
        wrapOuterMs: 2,
        verifyWrappedMs: 3,
        requestVersion: ZkPassportRequestVersion(
          requestId: 'request-a',
          createdAtMs: 4,
          nonce: 'nonce-a',
        ),
      );
      final j = full.toJson();
      expect(j['facematch_verified'], true);
      expect(j['verify_outer_ms'], 1);
      expect(j['wrap_outer_ms'], 2);
      expect(j['verify_wrapped_ms'], 3);
      expect(
        ZkPassportLocalRegistration.fromJson(j)?.requestVersion,
        full.requestVersion,
      );
    });

    test('fromJson parses fields, string ints, empty nullifier -> null', () {
      final r = ZkPassportLocalRegistration.fromJson({
        'registered': true,
        'nullifier_hex': '  hex  ',
        'registered_at_ms': '42',
        'facematch_verified': true,
        'verify_outer_ms': '7',
        'wrap_outer_ms': 8,
      });
      expect(r, isNotNull);
      expect(r!.registered, isTrue);
      expect(r.nullifierHex, 'hex');
      expect(r.registeredAtMs, 42);
      expect(r.facematchVerified, isTrue);
      expect(r.verifyOuterMs, 7);
      expect(r.wrapOuterMs, 8);

      final blank = ZkPassportLocalRegistration.fromJson({
        'registered': false,
        'nullifier_hex': '   ',
      });
      expect(blank!.nullifierHex, isNull);
    });

    test('fromJson rejects non-map', () {
      expect(ZkPassportLocalRegistration.fromJson(42), isNull);
    });
  });
}
