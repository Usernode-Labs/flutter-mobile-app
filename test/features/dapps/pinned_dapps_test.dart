import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/dapps/models/pinned_dapp.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinnedDapp.idForUrl', () {
    test('is a stable 12-char hex digest of the url', () {
      final id = PinnedDapp.idForUrl('https://echo.example.org');
      expect(id, hasLength(12));
      expect(RegExp(r'^[a-f0-9]{12}$').hasMatch(id), true);
      expect(PinnedDapp.idForUrl('https://echo.example.org'), id);
      expect(PinnedDapp.idForUrl('https://other.example.org'), isNot(id));
    });
  });

  group('PinnedDapp json round-trip', () {
    test('serializes and deserializes all fields', () {
      const dapp = PinnedDapp(
        id: 'abc123def456',
        name: 'Echo',
        url: 'https://echo.example.org',
        iconUrl: 'https://echo.example.org/icon.png',
        pinnedAtMs: 1234567890,
      );
      final restored = PinnedDapp.fromJson(dapp.toJson());
      expect(restored.id, dapp.id);
      expect(restored.name, dapp.name);
      expect(restored.url, dapp.url);
      expect(restored.iconUrl, dapp.iconUrl);
      expect(restored.pinnedAtMs, dapp.pinnedAtMs);
    });
  });

  group('pinnedDappsProvider', () {
    test('loads empty registry when nothing persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dapps = await container.read(pinnedDappsProvider.future);
      expect(dapps, isEmpty);
    });

    test('pin persists and unpin removes', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pinnedDappsProvider.notifier);
      final pinned = await notifier.pin(
        name: 'Echo',
        url: 'https://echo.example.org',
        iconUrl: 'https://echo.example.org/icon.png',
      );

      expect(pinned.id, PinnedDapp.idForUrl('https://echo.example.org'));
      expect(container.read(pinnedDappByIdProvider(pinned.id))?.name, 'Echo');

      final prefs = await SharedPreferences.getInstance();
      final persisted =
          jsonDecode(prefs.getString(PinnedDappsNotifier.prefsKey)!) as List;
      expect(persisted, hasLength(1));

      await notifier.unpin(pinned.id);
      expect(container.read(pinnedDappByIdProvider(pinned.id)), isNull);
    });

    test('re-pinning the same url replaces the entry and moves it first',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pinnedDappsProvider.notifier);
      await notifier.pin(
        name: 'Echo',
        url: 'https://echo.example.org',
        iconUrl: '',
      );
      await notifier.pin(
        name: 'Lastwin',
        url: 'https://lastwin.example.org',
        iconUrl: '',
      );
      final renamed = await notifier.pin(
        name: 'Echo v2',
        url: 'https://echo.example.org',
        iconUrl: '',
      );

      final dapps = await container.read(pinnedDappsProvider.future);
      expect(dapps, hasLength(2));
      expect(dapps.first.id, renamed.id);
      expect(dapps.first.name, 'Echo v2');
    });

    test('registry survives reload from persisted json', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(pinnedDappsProvider.notifier).pin(
            name: 'Echo',
            url: 'https://echo.example.org',
            iconUrl: '',
          );
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      final dapps = await second.read(pinnedDappsProvider.future);
      expect(dapps, hasLength(1));
      expect(dapps.single.name, 'Echo');
    });
  });
}
