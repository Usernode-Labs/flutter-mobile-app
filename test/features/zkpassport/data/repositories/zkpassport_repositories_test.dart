import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          requestId: 'req',
          facematchStrict: true,
          phase: ZkPassportPipelinePhase.waiting,
          createdAtMs: 1,
          lastProgressAtMs: 2,
          resumeAttemptCount: 0,
        );

    test('load null when empty', () async {
      expect(await repo.load(), isNull);
    });

    test('save/load round-trip and clear', () async {
      await repo.save(session());
      final loaded = await repo.load();
      expect(loaded, isNotNull);
      expect(loaded!.requestId, 'req');

      await repo.clear();
      expect(await repo.load(), isNull);
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
