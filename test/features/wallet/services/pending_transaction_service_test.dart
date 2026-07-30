import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/wallet/models/pending_transaction.dart';
import 'package:crypto_mobile_app/features/wallet/services/pending_transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await svc.storePendingTransaction(a);
    await svc.storePendingTransaction(b);

    expect(await svc.getPendingTransactionCount(), 2);
    expect(await svc.getAllPendingTransactions(), hasLength(2));

    // Re-storing the same storageKey de-duplicates.
    await svc.storePendingTransaction(a);
    expect(await svc.getPendingTransactionCount(), 2);

    // Matching by address + timestamp proximity.
    final matches = await svc.findMatchingTransactions(
      fromAddress: a.fromAddress,
      toAddress: 'aaaaaaaaaaaa',
      timestamp: now.add(const Duration(minutes: 2)),
    );
    expect(matches, hasLength(1));
    expect(matches.first.amount, 10);

    expect(
      await svc.getAmountForTransaction(
          fromAddress: a.fromAddress,
          toAddress: 'aaaaaaaaaaaa',
          timestamp: now),
      10,
    );
    // No match -> null (timestamp far outside tolerance).
    expect(
      await svc.getAmountForTransaction(
          fromAddress: a.fromAddress,
          toAddress: 'aaaaaaaaaaaa',
          timestamp: now.add(const Duration(hours: 5))),
      isNull,
    );

    // Remove one.
    await svc.removePendingTransaction(a);
    expect(await svc.getPendingTransactionCount(), 1);

    // Expired entries are dropped by cleanup.
    await svc.storePendingTransaction(tx(
        to: 'cccccccccccc',
        amount: 5,
        ts: now.subtract(const Duration(hours: 30))));
    await svc.cleanupTransactions();
    final remaining = await svc.getAllPendingTransactions();
    expect(remaining.any((t) => t.toAddress == 'cccccccccccc'), isFalse);

    await svc.clearAllPendingTransactions();
    expect(await svc.getPendingTransactionCount(), 0);
  });
}
