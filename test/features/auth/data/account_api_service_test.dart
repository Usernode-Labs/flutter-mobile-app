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
      onUnauthorized: () async => cleared = true,
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
}
