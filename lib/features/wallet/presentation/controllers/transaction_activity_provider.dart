import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/transaction_item.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/mempool_provider.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

/// Controller that combines mempool transactions and confirmed UTXOs
/// into a unified transaction activity list
class TransactionActivityController
    extends AsyncNotifier<List<TransactionItem>> {
  @override
  Future<List<TransactionItem>> build() async {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<TransactionItem>> _fetch() async {
    try {
      // Get active account address for filtering
      String? ownerAddress;
      try {
        final repo = await AccountsRepository.create();
        final acc = await repo.getActive();
        if (acc != null && acc.address.isNotEmpty) {
          ownerAddress = acc.address;
        }
      } catch (e) {
        LoggingService.instance
            .warn('Failed to get active account: $e', tag: 'ACTIVITY');
      }

      final transactions = <TransactionItem>[];

      // Fetch pending transactions from mempool
      try {
        final mempoolTxs = await ref.watch(walletMempoolProvider.future);
        LoggingService.instance.debug(
            'Mempool transactions: ${mempoolTxs.length}',
            tag: 'ACTIVITY');

        for (var i = 0; i < mempoolTxs.length; i++) {
          final tx = mempoolTxs[i];
          final item = TransactionItem.fromMempoolTx(
            tx: tx,
            ownerAddress: ownerAddress ?? '',
          );
          transactions.add(item);
          LoggingService.instance.debug(
              '  Mempool[$i]: ${item.type.name} - ${item.status.name} - ${item.amounts.length} assets',
              tag: 'ACTIVITY');
        }
      } catch (e, st) {
        LoggingService.instance.warn(
            'Failed to load mempool transactions: $e\$st',
            tag: 'ACTIVITY');
        // Continue even if mempool fails
      }

      // Fetch confirmed UTXOs
      try {
        final utxos = await ref.watch(walletUtxosProvider.future);
        LoggingService.instance
            .debug('Confirmed UTXOs: ${utxos.length}', tag: 'ACTIVITY');

        for (var i = 0; i < utxos.length; i++) {
          final utxo = utxos[i];
          try {
            // Generate commitment hex for ID via FRB helper
            final commitmentHex =
                frb_types.utxoCommitmentToHex(commitment: utxo.commitment);

            final item = TransactionItem.fromUtxo(
              utxo: utxo,
              commitmentHex: commitmentHex,
            );
            transactions.add(item);
            LoggingService.instance.debug(
                '  UTXO[$i]: ${item.type.name} - ${item.status.name} - ${item.amounts.length} assets - ID: ${commitmentHex.substring(0, 16)}...',
                tag: 'ACTIVITY');
          } catch (e) {
            LoggingService.instance
                .warn('Failed to parse UTXO[$i]: $e', tag: 'ACTIVITY');
          }
        }
      } catch (e, st) {
        LoggingService.instance
            .warn('Failed to load UTXOs: $e\$st', tag: 'ACTIVITY');
        // Continue even if UTXOs fail
      }

      // Sort: pending first, then confirmed
      transactions.sort((a, b) {
        if (a.status == TransactionStatus.pending &&
            b.status == TransactionStatus.confirmed) {
          return -1;
        }
        if (a.status == TransactionStatus.confirmed &&
            b.status == TransactionStatus.pending) {
          return 1;
        }
        return 0;
      });

      LoggingService.instance
          .debug('Total transactions: ${transactions.length}', tag: 'ACTIVITY');

      // Log final summary
      final pendingCount = transactions
          .where((t) => t.status == TransactionStatus.pending)
          .length;
      final confirmedCount = transactions
          .where((t) => t.status == TransactionStatus.confirmed)
          .length;
      final sentCount =
          transactions.where((t) => t.type == TransactionType.sent).length;
      final receivedCount =
          transactions.where((t) => t.type == TransactionType.received).length;

      LoggingService.instance.debug(
          'Summary: $pendingCount pending, $confirmedCount confirmed, $sentCount sent, $receivedCount received',
          tag: 'ACTIVITY');

      return transactions;
    } catch (e, st) {
      LoggingService.instance.error('Failed to fetch transaction activity',
          tag: 'ACTIVITY', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final transactionActivityProvider =
    AsyncNotifierProvider<TransactionActivityController, List<TransactionItem>>(
  TransactionActivityController.new,
);
