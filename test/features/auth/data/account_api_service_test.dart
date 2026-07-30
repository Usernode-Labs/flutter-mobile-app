import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

const _base = 'https://test.example.com/api/v3/mobile';

Map<String, dynamic> _envelope(Object data) => {'success': true, 'data': data};

const _meData = {
  'id': 123,
  'email': 'a@b.com',
  'display_name': 'Alice',
  'email_confirmed': true,
  'is_in_waitlist': false,
  'level': 'operator',
};

void main() {
  test('getMe sends Bearer, hits /me, parses envelope + level', () async {
    Uri? url;
    String? auth;
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      httpClient: MockClient((req) async {
        url = req.url;
        auth = req.headers['authorization'];
        return http.Response(jsonEncode(_envelope(_meData)), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

    final me = await service.getMe();

    expect(url!.path, '/api/v3/mobile/me');
    expect(auth, 'Bearer sess-1');
    expect(me.id, 123);
    expect(me.level, UserLevel.operator);
  });

  test('401 invokes onUnauthorized then throws', () async {
    var cleared = false;
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      onUnauthorized: (epoch) async => cleared = true,
      httpClient: MockClient((req) async => http.Response('{}', 401)),
    );

    await expectLater(
      service.getMe(),
      throwsA(isA<AccountApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(cleared, true);
  });

  test('non-success envelope throws', () async {
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      httpClient: MockClient((req) async => http.Response(
          jsonEncode({'success': false}), 200,
          headers: {'content-type': 'application/json'})),
    );
    await expectLater(service.getMe(), throwsA(isA<AccountApiException>()));
  });

  test('omits Authorization header when there is no token', () async {
    String? auth = 'unset';
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => '',
      httpClient: MockClient((req) async {
        auth = req.headers['authorization'];
        return http.Response(jsonEncode(_envelope(_meData)), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    await service.getMe();
    expect(auth, isNull);
  });

  test('network error maps to AccountApiException(0)', () async {
    final service = AccountApiService(
      baseUrl: _base,
      httpClient: MockClient((req) async => throw Exception('boom')),
    );
    await expectLater(
      service.getMe(),
      throwsA(isA<AccountApiException>()
          .having((e) => e.statusCode, 'statusCode', 0)),
    );
  });

  test('non-2xx (non-401) throws with the status code', () async {
    final service = AccountApiService(
      baseUrl: _base,
      httpClient: MockClient((req) async => http.Response('err', 500)),
    );
    await expectLater(
      service.getMe(),
      throwsA(isA<AccountApiException>()
          .having((e) => e.statusCode, 'statusCode', 500)),
    );
  });

  test('default base URL is derived when none is supplied', () async {
    Uri? url;
    final service = AccountApiService(
      httpClient: MockClient((req) async {
        url = req.url;
        return http.Response(jsonEncode(_envelope(_meData)), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    await service.getMe();
    expect(url!.path, endsWith('/me'));
    service.dispose();
  });

  test('AccountApiException.toString includes code and message', () {
    expect(AccountApiException(404, 'nope').toString(),
        'AccountApiException(404, nope)');
  });
}
