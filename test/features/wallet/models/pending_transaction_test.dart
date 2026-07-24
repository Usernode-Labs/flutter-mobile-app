import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/wallet/models/pending_transaction.dart';

void main() {
  PendingTransaction tx({
    String from = 'fromAddress0000',
    String to = 'toAddress00000000',
    double amount = 12.5,
    DateTime? ts,
    String? memo,
  }) =>
      PendingTransaction(
        fromAddress: from,
        toAddress: to,
        amount: amount,
        timestamp: ts ?? DateTime.utc(2024, 1, 1, 12, 0, 0),
        memo: memo,
      );

  group('serialization', () {
    test('toJson omits null memo; includes it when set', () {
      expect(tx().toJson().containsKey('memo'), isFalse);
      expect(tx(memo: 'hi').toJson()['memo'], 'hi');
    });

    test('json string round-trip', () {
      final a = tx(memo: 'note');
      final b = PendingTransaction.fromJsonString(a.toJsonString());
      expect(b, equals(a));
    });

    test('fromJson parses fields', () {
      final t = PendingTransaction.fromJson({
        'fromAddress': 'f',
        'toAddress': 't',
        'amount': 3.0,
        'timestamp': DateTime.utc(2024, 5, 6).toIso8601String(),
      });
      expect(t.fromAddress, 'f');
      expect(t.amount, 3.0);
      expect(t.memo, isNull);
    });
  });

  group('matches', () {
    test('true within tolerance and matching addresses', () {
      final t = tx();
      expect(
        t.matches(
          txFromAddress: 'fromAddress0000',
          txToAddress: 'toAddress00000000',
          txTimestamp: t.timestamp.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });

    test('false when outside timestamp tolerance', () {
      final t = tx();
      expect(
        t.matches(
          txFromAddress: null,
          txToAddress: null,
          txTimestamp: t.timestamp.add(const Duration(minutes: 20)),
        ),
        isFalse,
      );
    });

    test('false on address mismatch', () {
      final t = tx();
      expect(
        t.matches(
            txFromAddress: 'other',
            txToAddress: null,
            txTimestamp: t.timestamp),
        isFalse,
      );
      expect(
        t.matches(
            txFromAddress: null,
            txToAddress: 'other',
            txTimestamp: t.timestamp),
        isFalse,
      );
    });

    test('null addresses are treated as wildcards', () {
      final t = tx();
      expect(
        t.matches(
            txFromAddress: null, txToAddress: null, txTimestamp: t.timestamp),
        isTrue,
      );
    });
  });

  test('isExpired reflects age against maxAge', () {
    final old = tx(ts: DateTime.now().subtract(const Duration(hours: 30)));
    final fresh = tx(ts: DateTime.now().subtract(const Duration(hours: 1)));
    expect(old.isExpired(), isTrue);
    expect(fresh.isExpired(), isFalse);
  });

  test('storageKey combines timestamp, amount and address prefix', () {
    final t = tx(to: 'abcdef12345', amount: 9.5);
    final key = t.storageKey;
    expect(key, contains('9.50'));
    expect(key, endsWith('abcdef12')); // first 8 chars of toAddress
  });

  test('storageKey handles short address', () {
    expect(tx(to: 'abc').storageKey, endsWith('abc'));
  });

  test('equality and hashCode by value', () {
    expect(tx(memo: 'm'), equals(tx(memo: 'm')));
    expect(tx(memo: 'm').hashCode, tx(memo: 'm').hashCode);
    expect(tx(memo: 'm'), isNot(equals(tx(memo: 'n'))));
  });
}
