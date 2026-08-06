import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

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
  group('checkEmail', () {
    test('parses exists/password_set', () async {
      final r =
          await _repo(_client(200, {'exists': true, 'password_set': false}))
              .checkEmail('a@b.com');
      expect(r.exists, true);
      expect(r.passwordSet, false);
    });
    test('429 -> rateLimited', () async {
      expect(
        () =>
            _repo(_client(429, {'message': 'slow down'})).checkEmail('a@b.com'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.rateLimited)),
      );
    });
  });

  group('login', () {
    test('200 -> AuthSession', () async {
      // v4 shape: {success, token, user} — the user key, not participant.
      final r = await _repo(_client(200, {
        'success': true,
        'token': 'sess-1',
        'user': {
          'id': 7,
          'email': 'a@b.com',
          'display_name': 'Ann',
          'email_confirmed': true,
          'level': 'member',
        },
      })).login(email: 'a@b.com', password: 'pw');
      expect(r.token, 'sess-1');
      expect(r.participant.id, 7);
      expect(r.participant.displayName, 'Ann');
      expect(r.participant.emailConfirmed, true);
    });
    test('401 -> invalidCredentials', () async {
      expect(
        () => _repo(_client(
                401, {'success': false, 'error': 'Invalid email or password.'}))
            .login(email: 'a@b.com', password: 'x'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.invalidCredentials)),
      );
    });
  });

  group('requestOtp', () {
    test('200 completes', () async {
      await _repo(_client(200, {'message': 'sent'})).requestOtp('a@b.com');
    });
  });

  group('verifyOtp', () {
    test('200 -> set_password_token', () async {
      final r = await _repo(_client(200, {'set_password_token': 'spt-1'}))
          .verifyOtp(email: 'a@b.com', code: '123456');
      expect(r.setPasswordToken, 'spt-1');
    });
    test('422 -> invalidCode', () async {
      expect(
        () => _repo(_client(
                422, {'success': false, 'error': 'Invalid or expired code.'}))
            .verifyOtp(email: 'a@b.com', code: '000000'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.invalidCode)),
      );
    });
  });

  group('setPassword', () {
    test('sends bearer set_password_token and returns session', () async {
      String? auth;
      final r = await _repo(_client(
              200,
              {
                'success': true,
                'token': 'sess-2',
                'user': {
                  'id': 1,
                  'email': 'a@b.com',
                  'email_confirmed': false,
                  'level': 'guest',
                },
              },
              onReq: (req) => auth = req.headers['authorization']))
          .setPassword(
              setPasswordToken: 'spt-1',
              password: 'password1',
              passwordConfirmation: 'password1');
      expect(auth, 'Bearer spt-1');
      expect(r.token, 'sess-2');
    });
    test('422 -> validation', () async {
      expect(
        () => _repo(_client(422, {'success': false, 'error': 'too short'}))
            .setPassword(
                setPasswordToken: 't',
                password: 'x',
                passwordConfirmation: 'x'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.validation)),
      );
    });
    test('403 -> wrongToken', () async {
      expect(
        () => _repo(_client(403, {'message': 'nope'})).setPassword(
            setPasswordToken: 't',
            password: 'password1',
            passwordConfirmation: 'password1'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.wrongToken)),
      );
    });
    test('401 expired token -> wrongToken', () async {
      expect(
        () => _repo(_client(401, {
          'success': false,
          'error': 'Set-password token has expired or was already used.',
        })).setPassword(
            setPasswordToken: 'expired',
            password: 'password1',
            passwordConfirmation: 'password1'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.kind, 'kind', AuthErrorKind.wrongToken)
              .having(
                (e) => e.message,
                'message',
                'Set-password token has expired or was already used.',
              ),
        ),
      );
    });
  });

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
}
