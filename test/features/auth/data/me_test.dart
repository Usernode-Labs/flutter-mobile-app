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

    test('not authenticated -> guest, whatever is cached', () {
      for (final cached in [null, ...UserLevel.values]) {
        expect(
          resolveUserLevel(authenticated: false, me: null, cachedLevel: cached),
          UserLevel.guest,
          reason: '$cached',
        );
      }
    });

    test('backend level wins over the cache', () {
      expect(
        resolveUserLevel(
            authenticated: true,
            me: me(UserLevel.operator),
            cachedLevel: UserLevel.member),
        UserLevel.operator,
      );
      // The demotion case: a cached operator must not survive /me saying member.
      expect(
        resolveUserLevel(
            authenticated: true,
            me: me(UserLevel.member),
            cachedLevel: UserLevel.operator),
        UserLevel.member,
      );
    });

    test('falls back to the last confirmed tier while /me is unresolved', () {
      expect(
        resolveUserLevel(
            authenticated: true, me: null, cachedLevel: UserLevel.operator),
        UserLevel.operator,
        reason: 'an operator keeps working offline',
      );
      expect(
        resolveUserLevel(
            authenticated: true, me: null, cachedLevel: UserLevel.member),
        UserLevel.member,
      );
    });

    // Nothing confirmed yet -> the tier with no privileges. Never operator:
    // holding a local key is not authority, and a demoted member can still
    // have one.
    test('unconfirmed authenticated user is a member, never an operator', () {
      expect(
        resolveUserLevel(authenticated: true, me: null, cachedLevel: null),
        UserLevel.member,
      );
      // A stale `guest` cache on an authenticated session is incoherent;
      // resolve it to member rather than stripping them back to guest.
      expect(
        resolveUserLevel(
            authenticated: true, me: null, cachedLevel: UserLevel.guest),
        UserLevel.member,
      );
    });
  });
}
