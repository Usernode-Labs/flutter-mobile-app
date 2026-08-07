import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

void main() {
  group('Me.fromJson', () {
    test('parses fields', () {
      final me = Me.fromJson({
        'id': 123,
        'email': 'a@b.com',
        'display_name': 'Alice',
        'email_confirmed': true,
        'is_in_waitlist': false,
        'github': 'gh',
        'x': 'ex',
      });
      expect(me.id, 123);
      expect(me.email, 'a@b.com');
      expect(me.displayName, 'Alice');
      expect(me.emailConfirmed, true);
      expect(me.isInWaitlist, false);
      expect(me.github, 'gh');
      expect(me.x, 'ex');
    });

    test('accepts username-only accounts without an email', () {
      final me = Me.fromJson({
        'id': 123,
        'email': null,
        'email_confirmed': false,
      });

      expect(me.email, isEmpty);
    });
  });
}
