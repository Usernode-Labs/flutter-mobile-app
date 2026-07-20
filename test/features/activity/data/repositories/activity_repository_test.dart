import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_api_client.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_repository.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_session_store.dart';
import 'package:crypto_mobile_app/features/activity/domain/activity_assertion_provider.dart';

import '../../activity_test_fixtures.dart';

const _privateHeaders = {'cache-control': 'private, no-store'};

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('acquires one assertion and saves only a valid exchange', () async {
    var requests = 0;
    final api = ActivityApiClient(
      baseUrl: 'https://activity.example',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode(validActivitySessionJson()),
          200,
          headers: _privateHeaders,
        );
      }),
    );
    addTearDown(api.dispose);
    final store = ActivitySessionStore(
      baseUrl: api.baseUrl,
      secureStorage: secureStorage,
    );
    final repository = ActivityRepository(
      apiClient: api,
      sessionStore: store,
    );
    final assertions = _FakeAssertionProvider();

    await repository.establishSession(assertions);

    expect(assertions.calls, 1);
    expect(requests, 1);
    final stored = (await secureStorage.readAll()).values.single;
    expect(stored, contains(validActivityToken));
    expect(stored, isNot(contains(_FakeAssertionProvider.assertion)));
  });

  test('does not save or retry a failed exchange', () async {
    var requests = 0;
    final api = ActivityApiClient(
      baseUrl: 'https://activity.example',
      httpClient: MockClient((_) async {
        requests++;
        return http.Response(
          jsonEncode({'error': 'invalid_assertion'}),
          400,
        );
      }),
    );
    addTearDown(api.dispose);
    final repository = ActivityRepository(
      apiClient: api,
      sessionStore: ActivitySessionStore(
        baseUrl: api.baseUrl,
        secureStorage: secureStorage,
      ),
    );
    final assertions = _FakeAssertionProvider();

    await expectLater(
      repository.establishSession(assertions),
      throwsA(isA<ActivityApiException>()),
    );
    expect(assertions.calls, 1);
    expect(requests, 1);
    expect(await secureStorage.readAll(), isEmpty);
  });

  test('clears the secure session after unauthorized consumer response',
      () async {
    final api = ActivityApiClient(
      baseUrl: 'https://activity.example',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'error': 'unauthorized_consumer'}),
          401,
        ),
      ),
    );
    addTearDown(api.dispose);
    final store = ActivitySessionStore(
      baseUrl: api.baseUrl,
      secureStorage: secureStorage,
    );
    await store.save(ActivitySession.fromJson(validActivitySessionJson()));
    final repository = ActivityRepository(
      apiClient: api,
      sessionStore: store,
    );

    await expectLater(
      repository.getFeed(),
      throwsA(
        isA<ActivityApiException>().having(
          (error) => error.code,
          'code',
          ActivityApiErrorCode.unauthorizedConsumer,
        ),
      ),
    );
    expect(await secureStorage.readAll(), isEmpty);
    await expectLater(
      repository.getFeed(),
      throwsA(isA<ActivitySessionRequiredException>()),
    );
  });

  test('restores, uses, and explicitly clears a locally expired session',
      () async {
    var requests = 0;
    final api = ActivityApiClient(
      baseUrl: 'https://activity.example',
      httpClient: MockClient((request) async {
        requests++;
        expect(request.headers['authorization'], 'Bearer $validActivityToken');
        return http.Response(
          jsonEncode(validFeedPageJson()),
          200,
          headers: _privateHeaders,
        );
      }),
    );
    addTearDown(api.dispose);
    final store = ActivitySessionStore(
      baseUrl: api.baseUrl,
      secureStorage: secureStorage,
    );
    await store.save(
      ActivitySession.fromJson({
        ...validActivitySessionJson(),
        'expiresAt': '2020-01-01T00:00:00Z',
      }),
    );
    final repository = ActivityRepository(
      apiClient: api,
      sessionStore: store,
    );

    expect(await repository.restoreSession(), isTrue);
    expect((await repository.getFeed()).items, isNotEmpty);
    expect(requests, 1);

    await repository.clearSession();
    expect(await secureStorage.readAll(), isEmpty);
    await expectLater(
      repository.getFeed(),
      throwsA(isA<ActivitySessionRequiredException>()),
    );
  });
}

class _FakeAssertionProvider implements ActivityAssertionProvider {
  static const assertion = 'header.payload.single-use-assertion-value';
  int calls = 0;

  @override
  Future<String> acquireAssertion() async {
    calls++;
    return assertion;
  }
}
