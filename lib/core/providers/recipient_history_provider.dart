import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/identity_lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class RecipientHistoryNotifier extends AsyncNotifier<List<String>> {
  static const String _keyBase = 'wallet:recent_recipients';
  static const int _maxEntries = 5;

  static String get _key => NetworkPrefs.prefixAccountKey(_keyBase);

  @override
  Future<List<String>> build() async {
    // The key is bucket-derived and read once per build. Rebuild whenever the
    // identity that owns the bucket can have changed — an auth transition or
    // a mid-session account switch by the reconciler — so user B is never
    // shown (or merges into their bucket) user A's recent recipients.
    ref.watch(authStatusProvider);
    ref.watch(identityRevisionProvider);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> addRecipient(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;

    final current = state.value ?? const <String>[];
    final next = <String>[
      trimmed,
      ...current.where((entry) => entry != trimmed),
    ];
    final capped =
        next.length > _maxEntries ? next.sublist(0, _maxEntries) : next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, capped);
    state = AsyncValue.data(capped);
  }
}

final recipientHistoryProvider =
    AsyncNotifierProvider<RecipientHistoryNotifier, List<String>>(
  RecipientHistoryNotifier.new,
);
