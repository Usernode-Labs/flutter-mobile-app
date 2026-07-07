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

    test('re-pinning the same url replaces the entry in place', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pinnedDappsProvider.notifier);
      await notifier.pin(
        name: 'Echo',
        url: 'https://echo.example.org',
        iconUrl: '',
      );
      final lastwin = await notifier.pin(
        name: 'Lastwin',
        url: 'https://lastwin.example.org',
        iconUrl: '',
      );
      final renamed = await notifier.pin(
        name: 'Echo v2',
        url: 'https://echo.example.org',
        iconUrl: '',
      );

      // Registry order is the user's arranged widget order, so a refresh
      // (rename, icon re-send) must not shuffle it: Echo keeps its slot.
      final dapps = await container.read(pinnedDappsProvider.future);
      expect(dapps, hasLength(2));
      expect(dapps.first.id, lastwin.id);
      expect(dapps.last.id, renamed.id);
      expect(dapps.last.name, 'Echo v2');
    });

    test('reorder follows the given ids, tolerating unknown and missing ids',
        () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pinnedDappsProvider.notifier);
      final a = await notifier.pin(
          name: 'A', url: 'https://a.example.org', iconUrl: '');
      final b = await notifier.pin(
          name: 'B', url: 'https://b.example.org', iconUrl: '');
      final c = await notifier.pin(
          name: 'C', url: 'https://c.example.org', iconUrl: '');
      // Registry is newest-first: [c, b, a].

      final reordered = await notifier.reorder([a.id, c.id, b.id]);
      expect(reordered.map((d) => d.id).toList(), [a.id, c.id, b.id]);

      // Unknown ids are ignored; ids missing from the list keep their
      // relative order and are appended, so nothing can be dropped.
      final partial = await notifier.reorder(['bogus', b.id]);
      expect(partial.map((d) => d.id).toList(), [b.id, a.id, c.id]);

      // The new order is what gets persisted.
      final prefs = await SharedPreferences.getInstance();
      final persisted =
          jsonDecode(prefs.getString(PinnedDappsNotifier.prefsKey)!) as List;
      expect(
        persisted.map((e) => (e as Map<String, dynamic>)['id']).toList(),
        [b.id, a.id, c.id],
      );
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
