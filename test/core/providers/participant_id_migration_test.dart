import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _guestKey = 'testnet:acct:guest:leaderboard:participant_id';

String _accountKey() =>
    'testnet:acct:${NetworkPrefs.activeBucket}:leaderboard:participant_id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  group('migrateGuestParticipantId', () {
    test('moves the staged id into the active account bucket', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});
      NetworkPrefs.setActiveBucket('ut1accountaddr', guest: false);

      await migrateGuestParticipantId();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_accountKey()), 42);
      // A true move: the source is removed, so a later guest session can
      // never resolve this user's id out of the guest bucket.
      expect(prefs.getInt(_guestKey), isNull);
      expect(await loadParticipantId(), 42);
    });

    test('is a no-op while the guest bucket is active', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});

      await migrateGuestParticipantId();

      final prefs = await SharedPreferences.getInstance();
      // Nowhere to move to yet — the staged value must survive so the move
      // can happen once an account bucket becomes active.
      expect(prefs.getInt(_guestKey), 42);
    });

    test('is a no-op when nothing is staged', () async {
      NetworkPrefs.setActiveBucket('ut1accountaddr', guest: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_accountKey(), 7);

      await migrateGuestParticipantId();

      // The existing destination value is untouched.
      expect(prefs.getInt(_accountKey()), 7);
    });

    test('is idempotent and overwrites a stale destination value', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});
      NetworkPrefs.setActiveBucket('ut1accountaddr', guest: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_accountKey(), 7); // stale id from an older login

      await migrateGuestParticipantId();
      expect(prefs.getInt(_accountKey()), 42);

      // Re-running after a completed move changes nothing.
      await migrateGuestParticipantId();
      expect(prefs.getInt(_accountKey()), 42);
      expect(prefs.getInt(_guestKey), isNull);
    });
  });

  group('guest bucket staging helpers', () {
    test(
        'stageParticipantIdInGuestBucket writes the guest bucket even when '
        'another bucket is active', () async {
      NetworkPrefs.setActiveBucket('ut1previoususer', guest: false);

      await stageParticipantIdInGuestBucket(42);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_guestKey), 42);
      // The active (previous user's) bucket must NOT be polluted.
      expect(prefs.getInt(_accountKey()), isNull);
    });

    test('clearGuestParticipantId removes a staged id', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});

      await clearGuestParticipantId();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_guestKey), isNull);
    });
  });
}
