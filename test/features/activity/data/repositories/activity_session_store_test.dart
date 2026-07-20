import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_session_store.dart';

import '../../activity_test_fixtures.dart';

void main() {
  const secureStorage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('stores one endpoint-scoped secure session record', () async {
    final store = ActivitySessionStore(
      baseUrl: 'https://activity.example',
      secureStorage: secureStorage,
    );
    final session = ActivitySession.fromJson(validActivitySessionJson());

    await store.save(session);

    final stored = await secureStorage.readAll();
    expect(stored, hasLength(1));
    final decoded = jsonDecode(stored.values.single) as Map<String, dynamic>;
    expect(decoded['baseUrl'], 'https://activity.example');
    expect(decoded['accessToken'], validActivityToken);
    expect(stored.values.single, isNot(contains('assertion')));
    expect((await store.load())?.accessToken, validActivityToken);
  });

  test('clears a session from another Activity environment', () async {
    final first = ActivitySessionStore(
      baseUrl: 'https://activity-one.example',
      secureStorage: secureStorage,
    );
    await first.save(ActivitySession.fromJson(validActivitySessionJson()));

    final second = ActivitySessionStore(
      baseUrl: 'https://activity-two.example',
      secureStorage: secureStorage,
    );
    expect(await second.load(), isNull);
    expect(await secureStorage.readAll(), isEmpty);
  });

  test('keeps local expiry advisory and clears corrupt records', () async {
    final store = ActivitySessionStore(
      baseUrl: 'https://activity.example',
      secureStorage: secureStorage,
    );
    const key = 'activity:consumer-session:v1';
    FlutterSecureStorage.setMockInitialValues({
      key: jsonEncode({
        'baseUrl': 'https://activity.example',
        ...validActivitySessionJson(),
      }),
    });

    final expiredLocally = await store.load();
    expect(expiredLocally?.expiresAt, DateTime.utc(2030, 7, 27, 12));
    expect(await secureStorage.readAll(), isNotEmpty);

    FlutterSecureStorage.setMockInitialValues({key: '{not-json'});
    expect(await store.load(), isNull);
    expect(await secureStorage.readAll(), isEmpty);
  });
}
