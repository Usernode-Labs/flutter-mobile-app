// Block-production release gating (onboarding flow alignment).
//
// Producing blocks is a released capability: the platform surfaces
// `bp_released` on `/me` and `/wallet/provision`, the reconciler / meProvider
// persist it per account bucket, and NodeService only configures
// `builder.blockProducerSecretKey(...)` when the ACTIVE bucket's flag is
// true. These tests pin the persistence layer and the API parsing that
// feed that gate.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/block_production_store.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const address = 'ut1testaddressforbpgate';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkPrefs.setActiveBucket(address, guest: false);
  });

  tearDown(() {
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  group('block production store', () {
    test('defaults to NOT released when nothing was ever persisted', () async {
      // A node must never produce until the platform has said so at least
      // once — an absent flag reads as false, not true.
      expect(await loadBlockProductionReleased(), isFalse);
    });

    test('persists per account bucket and reads back from the active bucket',
        () async {
      await installBlockProductionReleasedInBucket(
        released: true,
        bucket: NetworkPrefs.bucketForAddress(address),
      );
      expect(await loadBlockProductionReleased(), isTrue);

      // A release can be revoked; the store follows the latest server word.
      await installBlockProductionReleasedInBucket(
        released: false,
        bucket: NetworkPrefs.bucketForAddress(address),
      );
      expect(await loadBlockProductionReleased(), isFalse);
    });

    test('a release for one account never leaks into another bucket', () async {
      await installBlockProductionReleasedInBucket(
        released: true,
        bucket: NetworkPrefs.bucketForAddress('ut1someotheraccount'),
      );
      // Active bucket (for `address`) still reads false.
      expect(await loadBlockProductionReleased(), isFalse);
    });

    test('guest bucket never inherits an account release', () async {
      await installBlockProductionReleasedInBucket(
        released: true,
        bucket: NetworkPrefs.bucketForAddress(address),
      );
      NetworkPrefs.setActiveBucket(null, guest: true);
      expect(await loadBlockProductionReleased(), isFalse);
    });
  });

  group('API parsing that feeds the gate', () {
    test('WalletProvisionResult parses bp_released (default false)', () {
      final released = WalletProvisionResult.fromJson(const {
        'address': 'ut1abc',
        'public_key': 'pk',
        'secret_key': 'sk',
        'bp_released': true,
      });
      expect(released.bpReleased, isTrue);

      final absent = WalletProvisionResult.fromJson(const {
        'address': 'ut1abc',
        'public_key': 'pk',
        'secret_key': 'sk',
      });
      expect(absent.bpReleased, isFalse);
    });

    test('Me parses has_platform_access / bp_requested / bp_released', () {
      final me = Me.fromJson(const {
        'id': 7,
        'email': 'bp@example.com',
        'email_confirmed': true,
        'level': 'member',
        'has_platform_access': true,
        'bp_requested': true,
        'bp_released': true,
      });
      expect(me.hasPlatformAccess, isTrue);
      expect(me.bpRequested, isTrue);
      expect(me.bpReleased, isTrue);

      final legacy = Me.fromJson(const {
        'id': 8,
        'email': 'old@example.com',
        'email_confirmed': true,
        'level': 'member',
      });
      // A backend that predates the fields must read as "not released".
      expect(legacy.hasPlatformAccess, isFalse);
      expect(legacy.bpRequested, isFalse);
      expect(legacy.bpReleased, isFalse);
    });
  });
}
