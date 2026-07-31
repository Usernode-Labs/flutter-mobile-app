import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/providers/recipient_history_provider.dart';

const _accountA = AccountStorageScope(
  network: 'testnet',
  bucket: 'bucket-a',
  accountId: 'account-a',
  address: 'address-a',
);

const _accountB = AccountStorageScope(
  network: 'internal',
  bucket: 'bucket-b',
  accountId: 'account-b',
  address: 'address-b',
);

final class _ControlledRecipientHistoryStore implements RecipientHistoryStore {
  _ControlledRecipientHistoryStore({
    Map<AccountStorageScope, List<String>>? values,
  }) : values = {
          for (final entry in (values ?? const {}).entries)
            entry.key: List<String>.of(entry.value),
        };

  final Map<AccountStorageScope, List<String>> values;
  final Completer<void> accountAReadStarted = Completer<void>();
  final Completer<void> releaseAccountARead = Completer<void>();
  final Completer<void> accountAWriteStarted = Completer<void>();
  final Completer<void> releaseAccountAWrite = Completer<void>();

  bool blockAccountARead = false;
  bool blockAccountAWrite = false;

  @override
  Future<List<String>> read(AccountStorageScope scope) async {
    if (scope == _accountA && blockAccountARead) {
      if (!accountAReadStarted.isCompleted) accountAReadStarted.complete();
      await releaseAccountARead.future;
    }
    return List<String>.of(values[scope] ?? const []);
  }

  @override
  Future<void> write(
    AccountStorageScope scope,
    List<String> recipients,
  ) async {
    if (scope == _accountA && blockAccountAWrite) {
      if (!accountAWriteStarted.isCompleted) accountAWriteStarted.complete();
      await releaseAccountAWrite.future;
    }
    values[scope] = List<String>.of(recipients);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shared-preferences store uses only the explicit account scope',
      () async {
    const store = SharedPreferencesRecipientHistoryStore();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _accountA.preferenceKey(
        SharedPreferencesRecipientHistoryStore.keyBase,
      ),
      ['recipient-a'],
    );
    await prefs.setStringList(
      _accountB.preferenceKey(
        SharedPreferencesRecipientHistoryStore.keyBase,
      ),
      ['recipient-b'],
    );

    expect(await store.read(_accountA), ['recipient-a']);
    expect(await store.read(_accountB), ['recipient-b']);

    await store.write(_accountA, ['new-a']);
    expect(await store.read(_accountA), ['new-a']);
    expect(await store.read(_accountB), ['recipient-b']);
  });

  test('late account-A read cannot publish into account-B provider state',
      () async {
    final store = _ControlledRecipientHistoryStore(values: {
      _accountA: ['recipient-a'],
      _accountB: ['recipient-b'],
    })
      ..blockAccountARead = true;
    final container = ProviderContainer(overrides: [
      recipientHistoryStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    final accountASubscription = container.listen(
      recipientHistoryProvider(_accountA),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(accountASubscription.close);
    await store.accountAReadStarted.future;

    final accountB =
        await container.read(recipientHistoryProvider(_accountB).future);
    expect(accountB, ['recipient-b']);

    store.releaseAccountARead.complete();
    final accountA =
        await container.read(recipientHistoryProvider(_accountA).future);

    expect(accountA, ['recipient-a']);
    expect(
      container.read(recipientHistoryProvider(_accountB)).value,
      ['recipient-b'],
    );
  });

  test('late account-A write stays in account-A storage and state', () async {
    final store = _ControlledRecipientHistoryStore(values: {
      _accountA: ['old-a'],
      _accountB: ['recipient-b'],
    })
      ..blockAccountAWrite = true;
    final container = ProviderContainer(overrides: [
      recipientHistoryStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(recipientHistoryProvider(_accountA).future);
    final write = container
        .read(recipientHistoryProvider(_accountA).notifier)
        .addRecipient('new-a');
    await store.accountAWriteStarted.future;

    // Simulate the UI switching to B while A's persistence is outstanding.
    expect(
      await container.read(recipientHistoryProvider(_accountB).future),
      ['recipient-b'],
    );

    store.releaseAccountAWrite.complete();
    await write;

    expect(store.values[_accountA], ['new-a', 'old-a']);
    expect(store.values[_accountB], ['recipient-b']);
    expect(
      container.read(recipientHistoryProvider(_accountA)).value,
      ['new-a', 'old-a'],
    );
    expect(
      container.read(recipientHistoryProvider(_accountB)).value,
      ['recipient-b'],
    );
  });

  test('recipient updates are deduplicated, serialized, and capped', () async {
    final store = _ControlledRecipientHistoryStore(values: {
      _accountA: ['one', 'two', 'three', 'four', 'five'],
    });
    final container = ProviderContainer(overrides: [
      recipientHistoryStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
    await container.read(recipientHistoryProvider(_accountA).future);

    final notifier =
        container.read(recipientHistoryProvider(_accountA).notifier);
    await Future.wait([
      notifier.addRecipient('two'),
      notifier.addRecipient('six'),
    ]);

    expect(store.values[_accountA], ['six', 'two', 'one', 'three', 'four']);
  });
}
