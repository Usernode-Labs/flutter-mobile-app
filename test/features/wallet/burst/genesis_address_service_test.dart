import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/wallet/burst/genesis_address_service.dart';

void main() {
  group('parseGenesisAddresses', () {
    test('extracts addresses from alloc genesis', () {
      final genesis = <String, dynamic>{
        'alloc': <String, dynamic>{
          'ut1alice': 100,
          'ut1bob': 200,
          'not-an-address': 300,
        },
      };

      expect(parseGenesisAddresses(genesis), ['ut1alice', 'ut1bob']);
    });

    test('extracts and deduplicates addresses from outputs genesis', () {
      final genesis = <String, dynamic>{
        'outputs': <Map<String, dynamic>>[
          <String, dynamic>{
            'recipient': <String, dynamic>{
              'key': <String, dynamic>{'pk_hash': 'ut1alice'},
            },
            'amount': 1,
          },
          <String, dynamic>{
            'recipient': <String, dynamic>{
              'key': <String, dynamic>{'pk_hash': 'ut1alice'},
            },
            'amount': 2,
          },
          <String, dynamic>{
            'recipient': <String, dynamic>{
              'key': <String, dynamic>{'pk_hash': 'ut1bob'},
            },
            'amount': 3,
          },
        ],
      };

      expect(parseGenesisAddresses(genesis), ['ut1alice', 'ut1bob']);
    });

    test('supports mixed alloc and outputs genesis', () {
      final genesis = <String, dynamic>{
        'alloc': <String, dynamic>{'ut1alice': 100},
        'outputs': <Map<String, dynamic>>[
          <String, dynamic>{
            'recipient': <String, dynamic>{
              'key': <String, dynamic>{'pk_hash': 'ut1bob'},
            },
            'amount': 1,
          },
        ],
      };

      expect(parseGenesisAddresses(genesis), ['ut1alice', 'ut1bob']);
    });
  });
}
