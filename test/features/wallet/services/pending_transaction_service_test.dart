import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/features/wallet/models/pending_transaction.dart';
import 'package:crypto_mobile_app/features/wallet/services/pending_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scope = AccountStorageScope(
    network: 'testnet',
    bucket: 'bucket-a',
    accountId: 'account-a',
    address: 'address-a',
  );
  const otherScope = AccountStorageScope(
    network: 'testnet',
    bucket: 'bucket-b',
    accountId: 'account-b',
    address: 'address-b',
  );

  PendingTransaction tx({
    String from = 'from000000000000',
    String to = 'to00000000000000',
    double amount = 10,
    DateTime? ts,
  }) =>
      PendingTransaction(
        fromAddress: from,
        toAddress: to,
        amount: amount,
        timestamp: ts ?? DateTime.now(),
      );

  test('store / query / match / cleanup lifecycle', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = await PendingTransactionService.getInstance();
    await svc.clearAllPendingTransactions();

    final now = DateTime.now();
    final a = tx(to: 'aaaaaaaaaaaa', amount: 10, ts: now);
    final b = tx(to: 'bbbbbbbbbbbb', amount: 20, ts: now);
    await svc.storePendingTransaction(scope, a);
    await svc.storePendingTransaction(scope, b);

    expect(await svc.getPendingTransactionCount(scope), 2);
    expect(await svc.getAllPendingTransactions(scope), hasLength(2));

    // Re-storing the same storageKey de-duplicates.
    await svc.storePendingTransaction(scope, a);
    expect(await svc.getPendingTransactionCount(scope), 2);

    // Matching by address + timestamp proximity.
    final matches = await svc.findMatchingTransactions(
      scope: scope,
      fromAddress: a.fromAddress,
      toAddress: 'aaaaaaaaaaaa',
      timestamp: now.add(const Duration(minutes: 2)),
    );
    expect(matches, hasLength(1));
    expect(matches.first.amount, 10);

    expect(
      await svc.getAmountForTransaction(
          scope: scope,
          fromAddress: a.fromAddress,
          toAddress: 'aaaaaaaaaaaa',
          timestamp: now),
      10,
    );
    // No match -> null (timestamp far outside tolerance).
    expect(
      await svc.getAmountForTransaction(
          scope: scope,
          fromAddress: a.fromAddress,
          toAddress: 'aaaaaaaaaaaa',
          timestamp: now.add(const Duration(hours: 5))),
      isNull,
    );

    // Remove one.
    await svc.removePendingTransaction(scope, a);
    expect(await svc.getPendingTransactionCount(scope), 1);

    // Expired entries are dropped by cleanup.
    await svc.storePendingTransaction(
        scope,
        tx(
            to: 'cccccccccccc',
            amount: 5,
            ts: now.subtract(const Duration(hours: 30))));
    await svc.cleanupTransactions(scope: scope);
    final remaining = await svc.getAllPendingTransactions(scope);
    expect(remaining.any((t) => t.toAddress == 'cccccccccccc'), isFalse);

    await svc.clearAllPendingTransactions();
    expect(await svc.getPendingTransactionCount(scope), 0);
  });

  test('ordinary scoped reads lazily remove expired rows', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = await PendingTransactionService.getInstance();
    await svc.clearAllPendingTransactions();

    await svc.storePendingTransaction(
      scope,
      tx(
        to: 'expired-address',
        ts: DateTime.now().subtract(const Duration(hours: 30)),
      ),
    );

    expect(await svc.getAllPendingTransactions(scope), isEmpty);
    expect(await svc.getPendingTransactionCount(scope), 0);
  });

  test('concurrent stores do not lose same-scope updates', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = await PendingTransactionService.getInstance();
    await svc.clearAllPendingTransactions();
    final now = DateTime.now();

    await Future.wait([
      for (var i = 0; i < 20; i++)
        svc.storePendingTransaction(
          scope,
          tx(
            to: 'address-$i',
            amount: i.toDouble(),
            ts: now.add(Duration(milliseconds: i)),
          ),
        ),
      for (var i = 0; i < 5; i++)
        svc.storePendingTransaction(
          otherScope,
          tx(
            to: 'other-$i',
            amount: i.toDouble(),
            ts: now.add(Duration(milliseconds: i)),
          ),
        ),
    ]);

    expect(await svc.getAllPendingTransactions(scope), hasLength(20));
    expect(await svc.getAllPendingTransactions(otherScope), hasLength(5));
  });
}
