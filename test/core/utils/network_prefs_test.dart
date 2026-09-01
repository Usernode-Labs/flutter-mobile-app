import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  tearDown(() => NetworkPrefs.setActiveBucket(null, guest: true));

  group('key prefixing', () {
    test('global keys pass through unchanged', () {
      expect(NetworkPrefs.prefixKey('app:theme_mode'), 'app:theme_mode');
    });

    test('prefixKey retains the fixed testnet storage namespace', () {
      expect(NetworkPrefs.currentNetwork, 'testnet');
      expect(NetworkPrefs.prefixKey('foo'), 'testnet:foo');
    });

    test('prefixAccountKey includes network + active bucket', () {
      NetworkPrefs.setActiveBucket(null, guest: true);
      expect(NetworkPrefs.prefixAccountKey('k'),
          'testnet:acct:${NetworkPrefs.guestBucket}:k');
      expect(NetworkPrefs.prefixAccountKey('app:theme_mode'),
          'app:theme_mode'); // global passthrough
    });
  });

  group('setActiveBucket', () {
    test('guest or empty address resolves to the guest bucket', () {
      NetworkPrefs.setActiveBucket('0xabc', guest: true);
      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
      NetworkPrefs.setActiveBucket('', guest: false);
      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
      NetworkPrefs.setActiveBucket(null, guest: false);
      expect(NetworkPrefs.activeBucket, NetworkPrefs.guestBucket);
    });

    test('address resolves to first 16 hex of sha256(address)', () {
      const addr = '0xdeadbeef';
      NetworkPrefs.setActiveBucket(addr, guest: false);
      final expected =
          sha256.convert(utf8.encode(addr)).toString().substring(0, 16);
      expect(NetworkPrefs.activeBucket, expected);
      expect(NetworkPrefs.activeBucket.length, 16);
    });
  });
}
