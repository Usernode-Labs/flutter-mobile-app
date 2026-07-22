import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/utils/network_prefs.dart';

class RecipientHistoryNotifier extends AsyncNotifier<List<String>> {
  static const String _keyBase = 'wallet:recent_recipients';
  static const int _maxEntries = 5;

  static String get _key => NetworkPrefs.prefixAccountKey(_keyBase);

  @override
  Future<List<String>> build() async {
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
