import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

void main() {
  group('Me.fromJson', () {
    test('parses fields and level', () {
      final me = Me.fromJson({
        'id': 123,
        'email': 'a@b.com',
        'display_name': 'Alice',
        'email_confirmed': true,
        'is_in_waitlist': false,
        'github': 'gh',
        'x': 'ex',
        'level': 'member',
      });
      expect(me.id, 123);
      expect(me.email, 'a@b.com');
      expect(me.displayName, 'Alice');
      expect(me.emailConfirmed, true);
      expect(me.isInWaitlist, false);
      expect(me.github, 'gh');
      expect(me.x, 'ex');
      expect(me.level, UserLevel.member);
    });

    test('maps level strings, unknown -> guest', () {
      expect(userLevelFromString('operator'), UserLevel.operator);
      expect(userLevelFromString('member'), UserLevel.member);
      expect(userLevelFromString('guest'), UserLevel.guest);
      expect(userLevelFromString(null), UserLevel.guest);
      expect(userLevelFromString('???'), UserLevel.guest);
    });
  });

  group('resolveUserLevel', () {
    Me me(UserLevel level) => Me(
          id: 1,
          email: 'a@b.com',
          emailConfirmed: true,
          level: level,
        );

    test('not authenticated -> guest regardless of onchain', () {
      expect(
        resolveUserLevel(
            authenticated: false, me: null, hasOnchainAccount: true),
        UserLevel.guest,
      );
    });

    test('authenticated uses backend level when present', () {
      expect(
        resolveUserLevel(
            authenticated: true,
            me: me(UserLevel.operator),
            hasOnchainAccount: false),
        UserLevel.operator,
      );
      expect(
        resolveUserLevel(
            authenticated: true,
            me: me(UserLevel.member),
            hasOnchainAccount: true),
        UserLevel.member,
      );
    });

    test('falls back to onchain flag until /me resolves', () {
      expect(
        resolveUserLevel(
            authenticated: true, me: null, hasOnchainAccount: true),
        UserLevel.operator,
      );
      expect(
        resolveUserLevel(
            authenticated: true, me: null, hasOnchainAccount: false),
        UserLevel.member,
      );
    });
  });
}
