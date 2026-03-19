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

  group('RegistrationResult hex-to-bech32m conversion', () {
    test('converts 64-char hex secret key to bech32m', () {
      final result = RegistrationResult.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid-1',
        'public_key': 'utpk1already',
        'secret_key_hex':
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        'address': 'ut1already',
        'tier': 'gold',
      });

      expect(result.secretKey, startsWith('utsk1'));
      expect(result.secretKey, isNot(contains('abcdef')));
      // 32 bytes → 52 five-bit groups + 6 checksum + 'utsk1' = 63 chars
      expect(result.secretKey.length, 63);
    });

    test('passes through bech32m secret key unchanged', () {
      final result = RegistrationResult.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid-1',
        'public_key': 'utpk1abc',
        'secret_key': 'utsk1somevalidbech32mdata',
        'address': 'ut1someaddr',
        'tier': 'gold',
      });

      expect(result.secretKey, 'utsk1somevalidbech32mdata');
    });

    test('passes through non-hex key unchanged', () {
      final result = RegistrationResult.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid-1',
        'public_key': '0xNotHex!',
        'secret_key': '0xAlsoNotHex!',
        'address': '0xAddr!',
        'tier': 'gold',
      });

      expect(result.secretKey, '0xAlsoNotHex!');
      expect(result.publicKey, '0xNotHex!');
    });

    test('converts hex public key and address', () {
      final hex32 =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final result = RegistrationResult.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid-1',
        'public_key_hex': hex32,
        'secret_key': 'utsk1passthrough',
        'public_key_hash': 'aabbccdd' * 5, // 40-char hex (20 bytes)
        'tier': 'gold',
      });

      expect(result.publicKey, startsWith('utpk1'));
      expect(result.address, startsWith('ut1'));
    });

    test('produces consistent encoding for same input', () {
      final hex =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final r1 = RegistrationResult.fromJson({
        'participant_id': 1,
        'identity_uid': 'uid',
        'public_key': 'utpk1x',
        'secret_key_hex': hex,
        'address': 'ut1x',
        'tier': 'gold',
      });
      final r2 = RegistrationResult.fromJson({
        'participant_id': 2,
        'identity_uid': 'uid',
        'public_key': 'utpk1x',
        'secret_key_hex': hex,
        'address': 'ut1x',
        'tier': 'gold',
      });

      expect(r1.secretKey, r2.secretKey);
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
  });
}
