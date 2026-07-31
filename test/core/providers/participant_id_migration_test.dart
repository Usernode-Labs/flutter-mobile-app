import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/participant_id_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _guestKey = 'testnet:acct:guest:leaderboard:participant_id';

String _keyFor(String bucket) =>
    'testnet:acct:$bucket:leaderboard:participant_id';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountBucket = 'bucket1234567890';

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  group('installParticipantIdInBucket', () {
    test('installs the id and removes the matching staged copy', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});

      await installParticipantIdInBucket(
        participantId: 42,
        bucket: accountBucket,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_keyFor(accountBucket)), 42);
      // A true move: the staged source is removed, so a later guest session
      // can never resolve this user's id out of the guest bucket.
      expect(prefs.getInt(_guestKey), isNull);
    });

    test('leaves a staged id belonging to ANOTHER user in place', () async {
      // User B logged in mid-reconcile: the guest bucket now stages B's id.
      // A's (stale) install must not consume it — it belongs to B's own
      // reconcile.
      SharedPreferences.setMockInitialValues({_guestKey: 100});

      await installParticipantIdInBucket(
        participantId: 42,
        bucket: accountBucket,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_keyFor(accountBucket)), 42);
      expect(prefs.getInt(_guestKey), 100);
    });

    test('overwrites a stale destination value and is idempotent', () async {
      SharedPreferences.setMockInitialValues({
        _guestKey: 42,
        _keyFor(accountBucket): 7, // stale id from an older login
      });

      await installParticipantIdInBucket(
        participantId: 42,
        bucket: accountBucket,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_keyFor(accountBucket)), 42);

      // Re-running after a completed install changes nothing.
      await installParticipantIdInBucket(
        participantId: 42,
        bucket: accountBucket,
      );
      expect(prefs.getInt(_keyFor(accountBucket)), 42);
      expect(prefs.getInt(_guestKey), isNull);
    });

    test('does not depend on which bucket is active', () async {
      // The reconcile addresses the provisioned account's bucket explicitly;
      // the active bucket (still guest during reconcile) must be irrelevant.
      NetworkPrefs.setActiveBucket('ut1someoneelse', guest: false);

      await installParticipantIdInBucket(
        participantId: 42,
        bucket: accountBucket,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_keyFor(accountBucket)), 42);
      expect(
        prefs.getInt(_keyFor(NetworkPrefs.bucketForAddress('ut1someoneelse'))),
        isNull,
      );
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
      expect(
        prefs.getInt(_keyFor(NetworkPrefs.bucketForAddress('ut1previoususer'))),
        isNull,
      );
    });

    test('clearGuestParticipantId removes a staged id', () async {
      SharedPreferences.setMockInitialValues({_guestKey: 42});

      await clearGuestParticipantId();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_guestKey), isNull);
    });

    test('loadParticipantIdInBucket reads an explicit bucket', () async {
      SharedPreferences.setMockInitialValues({_keyFor(accountBucket): 42});

      expect(await loadParticipantIdInBucket(accountBucket), 42);
      expect(await loadParticipantIdInBucket(NetworkPrefs.guestBucket), isNull);
    });

    test('loadParticipantId reads the ACTIVE bucket', () async {
      SharedPreferences.setMockInitialValues({
        _guestKey: 1,
        _keyFor(NetworkPrefs.bucketForAddress('ut1accountaddr')): 2,
      });

      expect(await loadParticipantId(), 1);
      NetworkPrefs.setActiveBucket('ut1accountaddr', guest: false);
      expect(await loadParticipantId(), 2);
    });
  });
}
