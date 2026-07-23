import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/node/node_mode.dart';

void main() {
  group('resolveNodeMode', () {
    test('keyed only when token + account + cached operator all hold', () {
      expect(
        resolveNodeMode(
          hasSessionToken: true,
          hasOnchainAccount: true,
          cachedLevel: UserLevel.operator,
        ),
        NodeMode.keyed,
      );
    });

    test('no token -> keyless even for a cached operator with a key', () {
      expect(
        resolveNodeMode(
          hasSessionToken: false,
          hasOnchainAccount: true,
          cachedLevel: UserLevel.operator,
        ),
        NodeMode.keyless,
        reason: 'a signed-out operator must not produce',
      );
    });

    test('no on-chain account -> keyless', () {
      expect(
        resolveNodeMode(
          hasSessionToken: true,
          hasOnchainAccount: false,
          cachedLevel: UserLevel.operator,
        ),
        NodeMode.keyless,
      );
    });

    test('member or guest with a leftover key -> keyless', () {
      for (final level in [UserLevel.member, UserLevel.guest, null]) {
        expect(
          resolveNodeMode(
            hasSessionToken: true,
            hasOnchainAccount: true,
            cachedLevel: level,
          ),
          NodeMode.keyless,
          reason: '$level must not produce on the strength of a local key',
        );
      }
    });

    test('a bare guest is keyless', () {
      expect(
        resolveNodeMode(
          hasSessionToken: false,
          hasOnchainAccount: false,
          cachedLevel: UserLevel.guest,
        ),
        NodeMode.keyless,
      );
    });
  });
}
