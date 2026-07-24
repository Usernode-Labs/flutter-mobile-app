import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';

ExplorerTransaction _tx({
  String id = 'tx-abcdef0123456789',
  String txType = 'transfer',
  String direction = 'in',
  double amount = 100,
  String status = 'confirmed',
  String? from,
  String? to,
  int? blockHeight,
}) =>
    ExplorerTransaction(
      id: id,
      txType: txType,
      direction: direction,
      amount: amount,
      tokenSymbol: 'TKN',
      timestamp: DateTime(2024, 1, 2, 3, 4, 5),
      status: status,
      fromAddress: from,
      toAddress: to,
      blockHeight: blockHeight,
    );

void main() {
  group('TransactionModel computed getters', () {
    TransactionModel model({
      double amount = 100,
      TransactionStatus status = TransactionStatus.completed,
      DateTime? timestamp,
      String id = '0123456789abcdef0123456789abcdef',
    }) =>
        TransactionModel(
          id: id,
          title: 't',
          subtitle: 's',
          amount: amount,
          tokenSymbol: 'TKN',
          type: TransactionType.receive,
          status: status,
          timestamp: timestamp ?? DateTime(2024, 1, 2, 3, 4, 5),
          icon: Icons.abc,
          color: const Color(0xFF000000),
        );

    test('isPositive reflects sign', () {
      expect(model(amount: 5).isPositive, isTrue);
      expect(model(amount: 0).isPositive, isFalse);
      expect(model(amount: -5).isPositive, isFalse);
    });

    test('formattedAmount prefixes + only when positive and groups thousands',
        () {
      expect(model(amount: 1500).formattedAmount, '+1,500');
      expect(model(amount: -2500).formattedAmount, '-2,500');
      expect(model(amount: 0).formattedAmount, '0');
    });

    test('statusText maps every status', () {
      expect(model(status: TransactionStatus.completed).statusText, 'Completed');
      expect(model(status: TransactionStatus.pending).statusText, 'Pending');
      expect(model(status: TransactionStatus.failed).statusText, 'Failed');
    });

    test('timeAgo covers day/hour/minute/just-now with pluralization', () {
      final now = DateTime.now();
      expect(model(timestamp: now.subtract(const Duration(days: 2))).timeAgo,
          '2 days ago');
      expect(model(timestamp: now.subtract(const Duration(days: 1, hours: 1)))
          .timeAgo, '1 day ago');
      expect(model(timestamp: now.subtract(const Duration(hours: 5))).timeAgo,
          '5 hours ago');
      expect(model(timestamp: now.subtract(const Duration(hours: 1))).timeAgo,
          '1 hour ago');
      expect(model(timestamp: now.subtract(const Duration(minutes: 3))).timeAgo,
          '3 minutes ago');
      expect(model(timestamp: now.subtract(const Duration(minutes: 1))).timeAgo,
          '1 minute ago');
      expect(model(timestamp: now.subtract(const Duration(seconds: 5))).timeAgo,
          'Just now');
    });

    test('formattedTimestamp is zero-padded ISO-ish', () {
      expect(model(timestamp: DateTime(2024, 3, 9, 7, 6, 5)).formattedTimestamp,
          '2024-03-09 07:06:05');
    });

    test('shortHash / fullSubtitle shorten long ids and pass short ones', () {
      final long = model(id: '0123456789abcdef0123456789abcdef');
      expect(long.shortHash, '01234567…89abcdef');
      expect(long.fullSubtitle, long.shortHash);
      expect(model(id: 'short').shortHash, 'short');
    });
  });

  group('TransactionModel.fromExplorerTransaction', () {
    test('reward maps title/type/subtitle and positive amount', () {
      final m = TransactionModel.fromExplorerTransaction(
        _tx(txType: 'reward', amount: -50, blockHeight: 42),
        DataSource.explorerPrimary,
        'me',
      );
      expect(m.type, TransactionType.reward);
      expect(m.title, 'Block Reward');
      expect(m.subtitle, 'Block 42');
      expect(m.amount, 50); // abs, incoming
      expect(m.dataSource, DataSource.explorerPrimary);
    });

    test('genesis maps title and subtitle', () {
      final m = TransactionModel.fromExplorerTransaction(
        _tx(txType: 'genesis'), DataSource.local, 'me');
      expect(m.type, TransactionType.genesis);
      expect(m.title, 'Genesis Allocation');
      expect(m.subtitle, 'Initial distribution');
    });

    test('outgoing transfer is negative with To: subtitle and counterparty', () {
      final m = TransactionModel.fromExplorerTransaction(
        _tx(direction: 'out', amount: 30, to: 'recipientAddress12345678'),
        DataSource.local,
        'me',
      );
      expect(m.type, TransactionType.send);
      expect(m.title, 'Sent');
      expect(m.amount, -30);
      expect(m.subtitle, startsWith('To: '));
      expect(m.counterpartyAddress, 'recipientAddress12345678');
    });

    test('incoming transfer is positive with From: subtitle', () {
      final m = TransactionModel.fromExplorerTransaction(
        _tx(direction: 'in', amount: 30, from: 'senderAddress12345678'),
        DataSource.local,
        'me',
      );
      expect(m.type, TransactionType.receive);
      expect(m.amount, 30);
      expect(m.subtitle, startsWith('From: '));
      expect(m.counterpartyAddress, 'senderAddress12345678');
    });

    test('transfer without addresses falls back to txType subtitle', () {
      final m = TransactionModel.fromExplorerTransaction(
        _tx(direction: 'out', to: null), DataSource.local, 'me');
      expect(m.subtitle, 'transfer');
    });

    test('status strings parse to the right enum, unknown -> completed', () {
      TransactionStatus s(String status) => TransactionModel
          .fromExplorerTransaction(_tx(status: status), DataSource.local, 'me')
          .status;
      expect(s('confirmed'), TransactionStatus.completed);
      expect(s('success'), TransactionStatus.completed);
      expect(s('pending'), TransactionStatus.pending);
      expect(s('unconfirmed'), TransactionStatus.pending);
      expect(s('failed'), TransactionStatus.failed);
      expect(s('error'), TransactionStatus.failed);
      expect(s('anything-else'), TransactionStatus.completed);
    });
  });

  group('WalletBalance', () {
    WalletBalance bal({
      double amount = 1234.5,
      DataSource source = DataSource.local,
      DateTime? lastUpdated,
    }) =>
        WalletBalance(
          tokenAmount: amount,
          tokenSymbol: 'TKN',
          totalBalance: BigInt.from(amount.toInt()),
          dataSource: source,
          lastUpdated: lastUpdated,
        );

    test('formattedTokenAmount fixes 2 decimals with symbol', () {
      expect(bal(amount: 12.5).formattedTokenAmount, '12.50 TKN');
    });

    test('getFormattedBalance compact uses K/M/B thresholds', () {
      expect(bal(amount: 500).getFormattedBalance(compact: true), '500.0');
      expect(bal(amount: 1500).getFormattedBalance(compact: true), '1.5K');
      expect(bal(amount: 2500000).getFormattedBalance(compact: true), '2.5M');
      expect(bal(amount: 3000000000).getFormattedBalance(compact: true), '3.0B');
    });

    test('getFormattedBalance full honors decimals', () {
      expect(bal(amount: 1234567).getFormattedBalance(decimals: 0), '1,234,567');
      expect(bal(amount: 1234.5).getFormattedBalance(decimals: 1), '1,234.5');
    });

    test('copyWith overrides only provided fields', () {
      final b = bal(amount: 10, source: DataSource.local);
      final c = b.copyWith(tokenAmount: 20, dataSource: DataSource.cached);
      expect(c.tokenAmount, 20);
      expect(c.dataSource, DataSource.cached);
      expect(c.tokenSymbol, b.tokenSymbol);
      expect(b.copyWith().tokenAmount, b.tokenAmount);
    });

    test('fromExplorerBalance copies fields', () {
      final ts = DateTime(2024, 1, 1);
      final wb = WalletBalance.fromExplorerBalance(ExplorerBalanceResponse(
        balance: 42.0,
        tokenSymbol: 'ABC',
        dataSource: DataSource.explorerSecondary,
        fetchedAt: ts,
      ));
      expect(wb.tokenAmount, 42.0);
      expect(wb.tokenSymbol, 'ABC');
      expect(wb.dataSource, DataSource.explorerSecondary);
      expect(wb.lastUpdated, ts);
    });

    test('dataSourceText maps every source', () {
      expect(bal(source: DataSource.explorerPrimary).dataSourceText,
          'Live (Primary)');
      expect(bal(source: DataSource.explorerSecondary).dataSourceText,
          'Live (Secondary)');
      expect(bal(source: DataSource.cached).dataSourceText, 'Cached');
      expect(bal(source: DataSource.local).dataSourceText, 'Local');
    });

    test('isLiveData only for explorer sources', () {
      expect(bal(source: DataSource.explorerPrimary).isLiveData, isTrue);
      expect(bal(source: DataSource.explorerSecondary).isLiveData, isTrue);
      expect(bal(source: DataSource.cached).isLiveData, isFalse);
      expect(bal(source: DataSource.local).isLiveData, isFalse);
    });

    test('lastUpdatedText: null empty, today time, other day MM/DD', () {
      expect(bal(lastUpdated: null).lastUpdatedText, '');

      final today = DateTime.now();
      final t = DateTime(today.year, today.month, today.day, 4, 5, 6);
      expect(bal(lastUpdated: t).lastUpdatedText, '4:05:06');

      expect(bal(lastUpdated: DateTime(2020, 3, 9)).lastUpdatedText, '03/09');
    });
  });

  group('Explorer model (de)serialization', () {
    test('ExplorerBalanceResponse.fromJson applies defaults + round-trips', () {
      final full = ExplorerBalanceResponse.fromJson(
          {'balance': 12.5, 'token_symbol': 'ABC'}, DataSource.cached);
      expect(full.balance, 12.5);
      expect(full.tokenSymbol, 'ABC');
      expect(full.dataSource, DataSource.cached);

      final empty =
          ExplorerBalanceResponse.fromJson({}, DataSource.local);
      expect(empty.balance, 0.0);
      expect(empty.tokenSymbol, 'TKN');

      expect(full.toJson()['balance'], 12.5);
    });

    test('ExplorerTransaction fromJson/toJson round-trips', () {
      final json = {
        'tx_id': 'abc',
        'tx_type': 'reward',
        'direction': 'in',
        'amount': 7.5,
        'timestamp_ms': 1700000000000,
        'status': 'confirmed',
        'source': 'src',
        'destination': 'dst',
        'block_height': 9,
        'block_hash': 'hash',
      };
      final tx = ExplorerTransaction.fromJson(json);
      expect(tx.id, 'abc');
      expect(tx.txType, 'reward');
      expect(tx.amount, 7.5);
      expect(tx.type, tx.direction); // legacy getter
      expect(tx.blockHeight, 9);

      final out = tx.toJson();
      expect(out['tx_id'], 'abc');
      expect(out['timestamp_ms'], 1700000000000);
      expect(out['destination'], 'dst');
    });

    test('ExplorerTransaction.fromJson defaults for missing fields', () {
      final tx = ExplorerTransaction.fromJson({});
      expect(tx.id, '');
      expect(tx.txType, 'transfer');
      expect(tx.direction, 'unknown');
      expect(tx.amount, 0.0);
      expect(tx.status, 'confirmed');
    });

    test('ExplorerTransactionsResponse parses items and round-trips', () {
      final resp = ExplorerTransactionsResponse.fromJson({
        'items': [
          {'tx_id': 'a', 'amount': 1},
          {'tx_id': 'b', 'amount': 2},
        ],
      }, DataSource.explorerPrimary);
      expect(resp.transactions, hasLength(2));
      expect(resp.transactions.first.id, 'a');
      expect(resp.dataSource, DataSource.explorerPrimary);

      final empty =
          ExplorerTransactionsResponse.fromJson({}, DataSource.local);
      expect(empty.transactions, isEmpty);

      expect((resp.toJson()['items'] as List), hasLength(2));
    });
  });
}
