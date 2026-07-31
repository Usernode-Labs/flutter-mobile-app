import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';

abstract interface class RecipientHistoryStore {
  Future<List<String>> read(AccountStorageScope scope);

  Future<void> write(AccountStorageScope scope, List<String> recipients);
}

final class SharedPreferencesRecipientHistoryStore
    implements RecipientHistoryStore {
  static const String keyBase = 'wallet:recent_recipients';

  const SharedPreferencesRecipientHistoryStore();

  @override
  Future<List<String>> read(AccountStorageScope scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(scope.preferenceKey(keyBase)) ?? const [];
  }

  @override
  Future<void> write(
    AccountStorageScope scope,
    List<String> recipients,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      scope.preferenceKey(keyBase),
      List<String>.of(recipients),
    );
  }
}

final recipientHistoryStoreProvider = Provider<RecipientHistoryStore>(
  (ref) => const SharedPreferencesRecipientHistoryStore(),
);

/// Recent recipients for exactly one [AccountStorageScope].
///
/// A notifier instance never consults the ambient active account, bucket, or
/// network. If a read or write for account A completes after the UI switches
/// to account B, it can update only A's family instance and A's storage key.
class RecipientHistoryNotifier
    extends FamilyAsyncNotifier<List<String>, AccountStorageScope> {
  static const int _maxEntries = 5;

  Future<void> _mutationTail = Future<void>.value();

  @override
  Future<List<String>> build(AccountStorageScope scope) =>
      ref.watch(recipientHistoryStoreProvider).read(scope);

  Future<void> addRecipient(String address) {
    final result = _mutationTail.then((_) => _addRecipient(address));
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _addRecipient(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;

    final current = state.value ?? await future;
    final next = <String>[
      trimmed,
      ...current.where((entry) => entry != trimmed),
    ];
    final capped = next.length > _maxEntries
        ? next.sublist(0, _maxEntries)
        : List<String>.of(next);

    await ref.read(recipientHistoryStoreProvider).write(arg, capped);
    state = AsyncValue.data(capped);
  }
}

final recipientHistoryProvider = AsyncNotifierProvider.family<
    RecipientHistoryNotifier, List<String>, AccountStorageScope>(
  RecipientHistoryNotifier.new,
);
