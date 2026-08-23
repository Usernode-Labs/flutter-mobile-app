import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

import '../../../helpers/session_authority_test_helpers.dart';

const _base = 'https://test.example.com/api/v3/mobile/auth';

MockClient _client(int status, Object body,
        {void Function(http.Request)? onReq}) =>
    MockClient((req) async {
      onReq?.call(req);
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    });

AuthRepository _repo(http.Client c) =>
    AuthRepository(httpClient: c, baseUrl: _base);

void main() {
  group('logout', () {
    test('sends bearer session token', () async {
      String? auth;
      await _repo(_client(200, {'message': 'Logged out.'},
              onReq: (req) => auth = req.headers['authorization']))
          .logout('sess-9');
      expect(auth, 'Bearer sess-9');
    });
    test('401 does not throw (already logged out)', () async {
      await _repo(_client(401, {'message': 'x'})).logout('sess-9');
    });
  });

  group('resolveBearerSession', () {
    test('derives the participant from authenticated /me', () async {
      late http.Request request;
      final session = await _repo(_client(
        200,
        {
          'success': true,
          'data': {
            'id': 7,
            'email': null,
            'display_name': 'Web User',
            'email_confirmed': false,
          },
        },
        onReq: (value) => request = value,
      )).resolveBearerSession('bearer-a');

      expect(request.method, 'GET');
      expect(
          request.url.toString(), 'https://test.example.com/api/v3/mobile/me');
      expect(request.headers['authorization'], 'Bearer bearer-a');
      expect(session.token, 'bearer-a');
      expect(session.participant.id, 7);
      expect(session.participant.email, isEmpty);
    });

    test('rejects an invalid bearer before it can become a session', () async {
      expect(
        () => _repo(_client(401, {
          'success': false,
          'error': 'Unauthenticated.',
        })).resolveBearerSession('expired'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.kind,
            'kind',
            AuthErrorKind.invalidCredentials,
          ),
        ),
      );
    });

    test('rejects a legacy user id that disagrees with the bearer owner',
        () async {
      expect(
        () => _repo(_client(200, {
          'success': true,
          'data': {
            'id': 7,
            'email': 'a@example.com',
            'email_confirmed': true,
          },
        })).resolveBearerSession(
          'bearer-a',
          legacyParticipantId: 8,
        ),
        throwsA(
          isA<AuthException>().having(
            (error) => error.kind,
            'kind',
            AuthErrorKind.validation,
          ),
        ),
      );
    });

    test('rejects a success response without an authenticated user', () async {
      expect(
        () => _repo(_client(200, {
          'success': true,
          'data': {'email': 'missing-id@example.com'},
        })).resolveBearerSession('bearer-a'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'Unexpected session validation response.',
          ),
        ),
      );
    });
  });

  group('confirmBearerSession', () {
    test('uses the exact credential sender for dedicated /me confirmation',
        () async {
      late AuthCredentialLease capturedCredential;
      late http.BaseRequest capturedRequest;
      final credential = testCredentialLease(
        epoch: 4,
        token: 'bearer-a',
        sessionId: 'session-a',
        credentialRef: 'credential-a',
        credentialGeneration: 2,
      );
      final repository = AuthRepository(
        httpClient: _client(500, const {}),
        baseUrl: _base,
        credentialRequestSender: ({
          required credential,
          required request,
        }) async {
          capturedCredential = credential;
          capturedRequest = request;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode({
              'success': true,
              'data': {
                'id': 7,
                'email': null,
                'display_name': 'Web User',
                'email_confirmed': false,
              },
            }))),
            200,
          );
        },
      );

      final session = await repository.confirmBearerSession(credential);

      expect(capturedCredential, same(credential));
      expect(capturedRequest.method, 'GET');
      expect(capturedRequest.url.toString(),
          'https://test.example.com/api/v3/mobile/me');
      expect(capturedRequest.headers['authorization'], 'Bearer bearer-a');
      expect(session.participant.id, 7);
      expect(session.token, 'bearer-a');
    });
  });
}
