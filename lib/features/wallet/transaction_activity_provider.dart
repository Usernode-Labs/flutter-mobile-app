import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_item.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/features/wallet/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/mempool_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('TransactionActivityProvider');

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
        _log.warn('Failed to get active account: $e');
      }

      final transactions = <TransactionItem>[];

      // Fetch pending transactions from mempool
      try {
        final mempoolTxs = await ref.watch(walletMempoolProvider.future);

        for (var i = 0; i < mempoolTxs.length; i++) {
          final tx = mempoolTxs[i];
          final item = TransactionItem.fromMempoolTx(
            tx: tx,
            ownerAddress: ownerAddress ?? '',
          );
          transactions.add(item);
        }
      } catch (e, st) {
        _log.warn('Failed to load mempool transactions: $e $st');
        // Continue even if mempool fails
      }

      // Fetch coinbase reward amount from epoch rewards
      BigInt? coinbaseRewardAmount;
      try {
        final epochRewards = await RustBackendService.instance.epochRewards();
        if (epochRewards != null) {
          coinbaseRewardAmount = epochRewards.rewardPerBlock;
          _log.debug('Coinbase reward amount: $coinbaseRewardAmount');
        }
      } catch (e) {
        _log.warn('Failed to fetch epoch rewards: $e');
        // Continue with null, will use default fallback value
      }

      // Fetch confirmed UTXOs (limit to 5 for display with mocks)
      try {
        final utxos = await ref.watch(walletUtxosProvider.future);
        _log.debug('Confirmed UTXOs: ${utxos.length}');

        // Take last 5 UTXOs (most recent ones)
        final limitedUtxos =
            utxos.length > 5 ? utxos.sublist(utxos.length - 5) : utxos;
        for (var i = 0; i < limitedUtxos.length; i++) {
          final utxo = limitedUtxos[i];
          try {
            // Generate commitment hex for ID via FRB helper
            final commitmentHex =
                frb_types.utxoCommitmentToHex(commitment: utxo.commitment);

            final item = TransactionItem.fromUtxo(
              utxo: utxo,
              commitmentHex: commitmentHex,
              coinbaseRewardAmount: coinbaseRewardAmount,
            );
            transactions.add(item);
          } catch (e) {
            _log.warn('Failed to parse UTXO[$i]: $e');
          }
        }
      } catch (e, st) {
        _log.warn('Failed to load UTXOs: $e $st');
        // Continue even if UTXOs fail
      }

      _log.debug('Total transactions: ${transactions.length}');

      return transactions;
    } catch (e, st) {
      _log.error('Failed to fetch transaction activity',
          error: e, stackTrace: st);
      rethrow;
    }
  }
}

final transactionActivityProvider =
    AsyncNotifierProvider<TransactionActivityController, List<TransactionItem>>(
  TransactionActivityController.new,
);
