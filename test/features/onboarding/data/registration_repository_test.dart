import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';

void main() {
  group('RegistrationResult.fromJson', () {
    test('parses new event schema with participant_id', () {
      final result = RegistrationResult.fromJson({
        'participant_id': 42,
        'identity_uid': 'uid-abc',
        'public_key': '0x123',
        'secret_key': '0xabc',
        'address': '0x999',
        'tier': 'gold',
        'event': {
          'event_id': 10,
          'name': 'Event Alpha',
          'ends_at': '2024-12-31T00:00:00Z',
        },
      });

      expect(result.participantId, 42);
      expect(result.identityUid, 'uid-abc');
      expect(result.eventId, 10);
      expect(result.eventName, 'Event Alpha');
      expect(result.eventEndsAt, '2024-12-31T00:00:00Z');
    });

    test('falls back to legacy phase payload', () {
      final result = RegistrationResult.fromJson({
        'id': 77,
        'identity_uid': 'uid-legacy',
        'public_key_hex': '0x987',
        'secret_key_hex': '0xfed',
        'public_key_hash': '0x111',
        'tier': 'silver',
        'phase': {
          'id': 2,
          'name': 'Phase 2',
          'ends_at': '2023-12-31T00:00:00Z',
        },
      });

      expect(result.participantId, 77);
      expect(result.eventId, 2);
      expect(result.eventName, 'Phase 2');
    });

    test('throws when participant_id missing', () {
      expect(
        () => RegistrationResult.fromJson({
          'identity_uid': 'uid',
          'public_key': '0x1',
          'secret_key': '0x2',
          'address': '0x3',
          'tier': 'bronze',
        }),
        throwsFormatException,
      );
    });
  });

  group('RegistrationRepository.register', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists participant id to shared preferences', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), equals('https://example.com'));
        expect(request.method, equals('POST'));
        return http.Response(
          '''
          {
            "success": true,
            "data": {
              "participant_id": 99,
              "identity_uid": "uid-abc",
              "public_key": "0x123",
              "secret_key": "0xabc",
              "address": "0x999",
              "tier": "gold"
            }
          }
          ''',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      final result = await repo.register(
        registrationCode: 'code',
        identifier: 'user',
      );

      expect(result.participantId, 99);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getInt(
          NetworkPrefs.prefixKey('leaderboard:participant_id'),
        ),
        equals(99),
      );
    });

    test('403 response throws RegistrationApiException with correct message',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false, "error": "Registration failed"}',
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having((e) => e.message, 'message',
                  contains('Registration is currently closed')),
        ),
      );
    });

    test('404 response throws with username/code message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false, "error": "Registration failed"}',
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message',
                  contains('Username not found or registration code invalid')),
        ),
      );
    });

    test('409 response throws with code-used message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false, "error": "Registration failed"}',
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                  (e) => e.message, 'message', contains('already been used')),
        ),
      );
    });

    test('404 with debug field extracts detailed message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false, "error": "Registration failed", "debug": "Participant not found."}',
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.message, 'message', 'Participant not found.'),
        ),
      );
    });

    test('422 response extracts Laravel validation error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false, "errors": {"identifier": ["The identifier field is required."]}}',
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message',
                  'The identifier field is required.'),
        ),
      );
    });

    test('422 without errors map falls back to generic message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"success": false}',
          422,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having((e) => e.message, 'message',
                  contains('username and registration code')),
        ),
      );
    });

    test('malformed JSON body falls back to status-code message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          'not valid json at all',
          500,
          headers: {'content-type': 'text/plain'},
        );
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(
          isA<RegistrationApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message',
                  contains('Please try again or contact support')),
        ),
      );
    });

    test('network error propagates (not swallowed)', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final repo = RegistrationRepository(
        endpoint: 'https://example.com',
        httpClient: mockClient,
      );

      expect(
        () => repo.register(registrationCode: 'code', identifier: 'user'),
        throwsA(isA<SocketException>()),
      );
    });
  });
}
