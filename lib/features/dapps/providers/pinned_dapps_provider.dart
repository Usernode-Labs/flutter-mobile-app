import 'dart:convert';

import 'package:crypto_mobile_app/features/dapps/models/pinned_dapp.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Locally persisted registry of homescreen-pinned dapps, newest first.
///
/// Shortcuts and widget tiles reference entries by [PinnedDapp.id]; the
/// `/dapps/pinned/:id` route resolves through this provider.
class PinnedDappsNotifier extends AsyncNotifier<List<PinnedDapp>> {
  static const prefsKey = 'pinned_dapps';

  @override
  Future<List<PinnedDapp>> build() => _load();

  Future<List<PinnedDapp>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PinnedDapp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<PinnedDapp> dapps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(dapps.map((d) => d.toJson()).toList()),
    );
  }

  /// Adds (or refreshes) a pinned dapp and returns it. Re-pinning the same
  /// URL replaces the existing entry and bumps it to the front.
  Future<PinnedDapp> pin({
    required String name,
    required String url,
    required String iconUrl,
  }) async {
    final current = await future;
    final pinned = PinnedDapp(
      id: PinnedDapp.idForUrl(url),
      name: name,
      url: url,
      iconUrl: iconUrl,
      pinnedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final updated = [
      pinned,
      ...current.where((d) => d.id != pinned.id),
    ];
    state = AsyncValue.data(updated);
    await _save(updated);
    return pinned;
  }

  Future<void> unpin(String id) async {
    final current = await future;
    final updated = current.where((d) => d.id != id).toList();
    state = AsyncValue.data(updated);
    await _save(updated);
  }
}

final pinnedDappsProvider =
    AsyncNotifierProvider<PinnedDappsNotifier, List<PinnedDapp>>(
  PinnedDappsNotifier.new,
);

final pinnedDappByIdProvider = Provider.family<PinnedDapp?, String>((ref, id) {
  final dapps = ref.watch(pinnedDappsProvider).valueOrNull;
  if (dapps == null) return null;
  for (final dapp in dapps) {
    if (dapp.id == id) return dapp;
  }
  return null;
});
