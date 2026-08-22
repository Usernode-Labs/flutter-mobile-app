import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => NetworkPrefs.setActiveBucket(null, guest: true));

  group('getNetwork / normalization', () {
    test('valid network is used, invalid/absent falls back to testnet',
        () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.${NetworkPrefs.networkKey}': 'internal'});
      expect(await NetworkPrefs.getNetwork(), 'internal');
      expect(NetworkPrefs.currentNetwork, 'internal');

      SharedPreferences.setMockInitialValues(
          {'flutter.${NetworkPrefs.networkKey}': 'bogus'});
      expect(await NetworkPrefs.getNetwork(), 'testnet');

      SharedPreferences.setMockInitialValues({});
      expect(await NetworkPrefs.getNetwork(), 'testnet');
    });

    test('init() primes the synchronous cache', () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.${NetworkPrefs.networkKey}': 'custom'});
      await NetworkPrefs.init();
      expect(NetworkPrefs.currentNetwork, 'custom');
    });

    test('the journal network replaces the compatibility cache exactly',
        () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.${NetworkPrefs.networkKey}': 'testnet'});
      await NetworkPrefs.init();

      await NetworkPrefs.adoptAuthorityNetwork('internal');

      expect(NetworkPrefs.currentNetwork, 'internal');
      expect(
        (await SharedPreferences.getInstance())
            .getString(NetworkPrefs.networkKey),
        'internal',
      );
      await expectLater(
        NetworkPrefs.adoptAuthorityNetwork('bogus'),
        throwsArgumentError,
      );
      expect(NetworkPrefs.currentNetwork, 'internal');
    });
  });

  group('key prefixing', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(
          {'flutter.${NetworkPrefs.networkKey}': 'testnet'});
      await NetworkPrefs.getNetwork();
    });

    test('global keys pass through unchanged', () {
      expect(NetworkPrefs.prefixKey(NetworkPrefs.networkKey),
          NetworkPrefs.networkKey);
      expect(NetworkPrefs.prefixKeyWith('app:theme_mode', 'internal'),
          'app:theme_mode');
    });

    test('prefixKey / prefixKeyWith add the network', () {
      expect(NetworkPrefs.prefixKey('foo'), 'testnet:foo');
      expect(NetworkPrefs.prefixKeyWith('foo', 'internal'), 'internal:foo');
    });

    test('prefixAccountKey includes network + active bucket', () {
      NetworkPrefs.setActiveBucket(null, guest: true);
      expect(NetworkPrefs.prefixAccountKey('k'),
          'testnet:acct:${NetworkPrefs.guestBucket}:k');
      expect(NetworkPrefs.prefixAccountKey(NetworkPrefs.networkKey),
          NetworkPrefs.networkKey); // global passthrough
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
