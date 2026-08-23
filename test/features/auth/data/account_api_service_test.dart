import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/features/auth/data/account_api_service.dart';

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

void _publishAuthenticatedIdentity({int epoch = 7}) {
  IdentitySnapshots.publish(Identity(
    epoch: epoch,
    phase: IdentityPhase.ready,
    participantId: 1,
    accountId: 'account-1',
    address: 'address-1',
    sessionId: 'session-a',
    credentialRef: 'credential-a',
    credentialGeneration: 3,
  ));
}

void main() {
  setUp(IdentitySnapshots.reset);
  tearDown(IdentitySnapshots.reset);

  test('getMe sends Bearer, hits /me, parses envelope + level', () async {
    _publishAuthenticatedIdentity();
    Uri? url;
    String? auth;
    final client = MockClient((req) async {
      url = req.url;
      auth = req.headers['authorization'];
      return http.Response(jsonEncode(_envelope(_meData)), 200,
          headers: {'content-type': 'application/json'});
    });
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      httpClient: client,
    );

    final me = await service.getMe();

    expect(url!.path, '/api/v3/mobile/me');
    expect(auth, 'Bearer sess-1');
    expect(me.id, 123);
  });

  test('in-flight getMe keeps its captured bearer across identity replacement',
      () async {
    _publishAuthenticatedIdentity();
    final requestSeen = Completer<http.Request>();
    final response = Completer<http.Response>();
    final client = MockClient((request) {
      requestSeen.complete(request);
      return response.future;
    });
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      httpClient: client,
    );

    final pending = service.getMe();
    final capturedRequest = await requestSeen.future;
    _publishAuthenticatedIdentity(epoch: 8);
    response.complete(http.Response(
      jsonEncode(_envelope(_meData)),
      200,
      headers: {'content-type': 'application/json'},
    ));
    final me = await pending;

    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url.path, '/api/v3/mobile/me');
    expect(capturedRequest.headers['authorization'], 'Bearer sess-1');
    expect(me.id, 123);
  });

  test('401 invokes onUnauthorized then throws', () async {
    _publishAuthenticatedIdentity();
    AuthCredentialLease? rejectedCredential;
    final client = MockClient((req) async => http.Response('{}', 401));
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      onUnauthorized: (credential) async {
        rejectedCredential = credential;
      },
      httpClient: client,
    );

    await expectLater(
      service.getMe(),
      throwsA(isA<AccountApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(rejectedCredential?.epoch, 7);
    expect(rejectedCredential?.token, 'sess-1');
    expect(rejectedCredential?.sessionId, 'session-a');
    expect(rejectedCredential?.credentialRef, 'credential-a');
    expect(rejectedCredential?.credentialGeneration, 3);
  });

  test('missing token under an authenticated identity is repaired, not sent',
      () async {
    IdentitySnapshots.publish(const Identity(
      epoch: 9,
      phase: IdentityPhase.ready,
      participantId: 1,
      accountId: 'account-1',
      address: 'address-1',
    ));
    var sent = false;
    int? missingEpoch;
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => null,
      onCredentialMissing: (epoch) async => missingEpoch = epoch,
      httpClient: MockClient((req) async {
        sent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.getMe(),
      throwsA(isA<StaleAuthCredentialException>()),
    );
    expect(missingEpoch, 9);
    expect(sent, isFalse);
  });

  test('non-success envelope throws', () async {
    _publishAuthenticatedIdentity();
    final client = MockClient((req) async => http.Response(
        jsonEncode({'success': false}), 200,
        headers: {'content-type': 'application/json'}));
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'sess-1',
      httpClient: client,
    );
    await expectLater(service.getMe(), throwsA(isA<AccountApiException>()));
  });

  test('stored token outside an authenticated identity is never attached',
      () async {
    var sent = false;
    final service = AccountApiService(
      baseUrl: _base,
      tokenProvider: () async => 'stale-token',
      httpClient: MockClient((req) async {
        sent = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.getMe(),
      throwsA(isA<StaleAuthCredentialException>()),
    );
    expect(sent, isFalse);
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
