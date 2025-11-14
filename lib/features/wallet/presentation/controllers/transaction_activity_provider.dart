import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/wallet/data/models/transaction_item.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/mempool_provider.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
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

        for (var i = 0; i < mempoolTxs.length; i++) {
          final tx = mempoolTxs[i];
          final item = TransactionItem.fromMempoolTx(
            tx: tx,
            ownerAddress: ownerAddress ?? '',
          );
          transactions.add(item);
        }
      } catch (e, st) {
        LoggingService.instance.warn(
            'Failed to load mempool transactions: $e $st',
            tag: 'ACTIVITY');
        // Continue even if mempool fails
      }

      // Add mock transactions first (5 mock transactions)
      final mockTransactions = _generateMockTransactions();
      transactions.addAll(mockTransactions);

      // Fetch coinbase reward amount from epoch rewards
      BigInt? coinbaseRewardAmount;
      try {
        final epochRewards = await RustBackendService.instance.epochRewards();
        if (epochRewards != null) {
          coinbaseRewardAmount = epochRewards.rewardPerBlock;
          LoggingService.instance.debug(
              'Coinbase reward amount: $coinbaseRewardAmount',
              tag: 'ACTIVITY');
        }
      } catch (e) {
        LoggingService.instance
            .warn('Failed to fetch epoch rewards: $e', tag: 'ACTIVITY');
        // Continue with null, will use default fallback value
      }

      // Fetch confirmed UTXOs (limit to 5 for display with mocks)
      try {
        final utxos = await ref.watch(walletUtxosProvider.future);
        LoggingService.instance
            .debug('Confirmed UTXOs: ${utxos.length}', tag: 'ACTIVITY');

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
            LoggingService.instance
                .warn('Failed to parse UTXO[$i]: $e', tag: 'ACTIVITY');
          }
        }
      } catch (e, st) {
        LoggingService.instance
            .warn('Failed to load UTXOs: $e $st', tag: 'ACTIVITY');
        // Continue even if UTXOs fail
      }

      LoggingService.instance.debug(
          'Total transactions: ${transactions.length} (${mockTransactions.length} mock + ${transactions.length - mockTransactions.length} real)',
          tag: 'ACTIVITY');

      return transactions;
    } catch (e, st) {
      LoggingService.instance.error('Failed to fetch transaction activity',
          tag: 'ACTIVITY', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Generate mock transactions for demonstration purposes
  List<TransactionItem> _generateMockTransactions() {
    return [
      // Received transaction 1: 25 TKN
      TransactionItem(
        id: '0x3a7f8b2e9d4c1f6a8e5b3d7c9a2f4e6b8d1a3c5e7f9b2d4a6c8e1f3a5b7d9c2e4',
        type: TransactionType.received,
        status: TransactionStatus.confirmed,
        amounts: [
          AssetAmount(
            tokenId: 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG',
            amount: BigInt.from(25),
          ),
        ],
        recipientAddress: 'abc123def456',
        fee: null,
      ),
      // Received transaction 2: 42 TKN
      TransactionItem(
        id: '0x7c2e4f9b1d6a8e3c5f7b9d2a4e6c8f1b3d5a7c9e2f4b6d8a1c3e5f7b9d2c4e6a8',
        type: TransactionType.received,
        status: TransactionStatus.confirmed,
        amounts: [
          AssetAmount(
            tokenId: 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG',
            amount: BigInt.from(42),
          ),
        ],
        recipientAddress: 'xyz789ghi012',
        fee: null,
      ),
      // Sent transaction 1: 15 TKN
      TransactionItem(
        id: '0x9e4b7d2c5f8a1e6b3d9c4f7a2e5b8d1c6f9a3e7b2d5c8f1a4e7b3d6c9f2a5e8b1',
        type: TransactionType.sent,
        status: TransactionStatus.confirmed,
        amounts: [
          AssetAmount(
            tokenId: 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG',
            amount: BigInt.from(15),
          ),
        ],
        recipientAddress: 'mno345pqr678',
        fee: null,
      ),
      // Sent transaction 2: 38 TKN (pending)
      TransactionItem(
        id: '0x2f5b8d1e7c4a9e6b2d8c5f7a1e4b7d9c3f6a8e2b5d7c9f1a4e6b8d2c5f7a9e3b6',
        type: TransactionType.sent,
        status: TransactionStatus.pending,
        amounts: [
          AssetAmount(
            tokenId: 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG',
            amount: BigInt.from(38),
          ),
        ],
        recipientAddress: 'jkl901stu234',
        fee: null,
      ),
      // Sent transaction 3: 55 TKN
      TransactionItem(
        id: '0x6d9c2e5a8b1f4d7c3e6a9b2f5d8c1a4e7b9d3f6c8a2e5b7d1c4f6a9e3b5d8c2a7',
        type: TransactionType.sent,
        status: TransactionStatus.confirmed,
        amounts: [
          AssetAmount(
            tokenId: 'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG',
            amount: BigInt.from(55),
          ),
        ],
        recipientAddress: 'vwx567yza890',
        fee: null,
      ),
    ];
  }
}

final transactionActivityProvider =
    AsyncNotifierProvider<TransactionActivityController, List<TransactionItem>>(
  TransactionActivityController.new,
);
