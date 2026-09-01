import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  setUp(() {
    // Reset to the default guest bucket between tests.
    NetworkPrefs.setActiveBucket(null, guest: true);
  });

  test('guest / null address resolve to the guest bucket', () {
    NetworkPrefs.setActiveBucket(null, guest: false);
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    NetworkPrefs.setActiveBucket('addr', guest: true);
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    NetworkPrefs.setActiveBucket('', guest: false);
    expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
  });

  test('address resolves to first 16 hex of sha256(address)', () {
    NetworkPrefs.setActiveBucket('usernode-address', guest: false);
    final expected = sha256
        .convert(utf8.encode('usernode-address'))
        .toString()
        .substring(0, 16);
    expect(NetworkPrefs.activeBucket, expected);
    expect(NetworkPrefs.activeBucket.length, 16);
  });

  test('prefixAccountKey buckets by fixed testnet namespace + identity', () {
    NetworkPrefs.setActiveBucket(null, guest: true);
    final key = NetworkPrefs.prefixAccountKey('onboarding:completed');
    expect(key,
        '${NetworkPrefs.currentNetwork}:acct:${NetworkPrefs.guestBucket}:onboarding:completed');

    NetworkPrefs.setActiveBucket('addr-x', guest: false);
    final key2 = NetworkPrefs.prefixAccountKey('onboarding:completed');
    expect(key2.startsWith('${NetworkPrefs.currentNetwork}:acct:'), isTrue);
    expect(key2, isNot(equals(key))); // different bucket → different key
  });

  test('global keys pass through prefixAccountKey unchanged', () {
    expect(NetworkPrefs.prefixAccountKey('app:theme_mode'), 'app:theme_mode');
  });
}
