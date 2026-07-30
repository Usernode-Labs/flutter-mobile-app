import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

const _guestKey = 'testnet:acct:guest:leaderboard:participant_id';

String _accountKey() =>
    'testnet:acct:${NetworkPrefs.activeBucket}:leaderboard:participant_id';

Map<String, dynamic> _accountJson(String id, String address) => {
      'id': id,
      'name': 'Node Account',
      'createdAt': '2026-01-01T00:00:00.000',
      'derivationPath': 'imported',
      'hdIndex': 0,
      'address': address,
      'publicKey': 'utpk1$address',
      'backupConfirmed': true,
      'isDemo': false,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
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

  group('activateBucketForSession', () {
    const address = 'ut1activeaccount';
    final bucket = NetworkPrefs.bucketForAddress(address);
    final registry = {
      'testnet:accounts:index': jsonEncode([_accountJson('acc_1', address)]),
      'testnet:accounts:activeId': 'acc_1',
    };

    test('activates the account bucket when it belongs to the session user',
        () async {
      SharedPreferences.setMockInitialValues({
        ...registry,
        // A past reconcile recorded participant 7 as this bucket's owner.
        'testnet:acct:$bucket:leaderboard:participant_id': 7,
      });
      await NetworkPrefs.init();

      await activateBucketForSession(7);

      expect(NetworkPrefs.activeBucket, bucket);
    });

    test(
        'stays on the guest bucket when the active account belongs to '
        'another user', () async {
      SharedPreferences.setMockInitialValues({
        ...registry,
        // The device's active account was reconciled for participant 7...
        'testnet:acct:$bucket:leaderboard:participant_id': 7,
      });
      await NetworkPrefs.init();

      // ...but participant 8 is the one signing in. Their identity is
      // unknown until reconcile — the previous user's bucket must not be
      // read or written.
      await activateBucketForSession(8);

      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    });

    test('stays on the guest bucket when ownership was never recorded',
        () async {
      SharedPreferences.setMockInitialValues({...registry});
      await NetworkPrefs.init();

      await activateBucketForSession(7);

      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    });

    test('resolves to the guest bucket when no local account exists', () async {
      await activateBucketForSession(7);

      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    });
  });
}
