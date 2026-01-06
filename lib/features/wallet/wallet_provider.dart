import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/wallet/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/token_registry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('usernode/WalletProvider');

class WalletState {
  final WalletBalance balance;
  final List<TransactionModel> recent;

  const WalletState({required this.balance, required this.recent});
}

class WalletController extends AsyncNotifier<WalletState> {
  // Empty transaction list - real data would come from blockchain/API
  final List<TransactionModel> _transactions = [];

  @override
  Future<WalletState> build() async {
    final balance = await _calculateBalance();
    return WalletState(
      balance: balance,
      recent: _transactions.take(10).toList(),
    );
  }

  /// Calculate wallet balance from UTXOs
  Future<WalletBalance> _calculateBalance() async {
    try {
      // Get UTXOs from existing provider
      final utxos = await ref.watch(walletUtxosProvider.future);

      // Aggregate balances by token_id
      final Map<String, BigInt> balancesByToken = {};
      String? primaryTokenSymbol;

      // Extract asset data from UTXOs via JSON serialization
      for (var i = 0; i < utxos.length; i++) {
        try {
          final ownedUtxo = utxos[i];

          // Serialize UTXO to JSON string
          final jsonStr = frb_types.utxoToJson(utxo: ownedUtxo.utxo);
          final utxoData = json.decode(jsonStr) as Map<String, dynamic>;

          // Extract assets array
          final assetsJson = utxoData['assets'] as List<dynamic>?;
          if (assetsJson == null || assetsJson.isEmpty) {
            _log.debug('  UTXO[$i]: No assets');
            continue;
          }

          // Aggregate balances by token_id
          for (final assetJson in assetsJson) {
            final tokenId = assetJson['token_id'] as String;
            final balance = BigInt.from(assetJson['balance'] as int);

            balancesByToken[tokenId] =
                (balancesByToken[tokenId] ?? BigInt.zero) + balance;
          }
        } catch (e, st) {
          _log.error('Failed to parse UTXO[$i]', error: e, stackTrace: st);
        }
      }

      // Calculate totals
      final totalBalance = balancesByToken.values.fold<BigInt>(
        BigInt.zero,
        (sum, balance) => sum + balance,
      );

      // Get primary token info (first token or default)
      if (balancesByToken.isNotEmpty) {
        final primaryTokenId = balancesByToken.keys.first;
        final metadata = _getTokenMetadata(primaryTokenId);
        primaryTokenSymbol = metadata['symbol'] as String;
      } else {
        primaryTokenSymbol = 'TOKENS'; // Default fallback
      }

      // Convert BigInt to double for display
      // Use toInt() instead of toDouble() to avoid precision issues with very large numbers
      final tokenAmount = totalBalance.toInt().toDouble();

      return WalletBalance(
        tokenAmount: tokenAmount,
        tokenSymbol: primaryTokenSymbol,
        usdValue: 0.0, // TODO: Add USD value calculation
        totalBalance: totalBalance,
      );
    } catch (e, st) {
      _log.error('Failed to calculate wallet balance',
          error: e, stackTrace: st);
      // Return fallback balance
      return WalletBalance(
        tokenAmount: 0.0,
        tokenSymbol: 'TOKENS',
        usdValue: 0.0,
        totalBalance: BigInt.zero,
      );
    }
  }

  /// Get token metadata (name, symbol) for a given token ID
  Map<String, String> _getTokenMetadata(String tokenId) {
    final metadata = TokenRegistry.instance.getMetadataOrFallback(tokenId);
    return {
      'name': metadata.name,
      'symbol': metadata.symbol,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    try {
      final balance = await _calculateBalance();
      state = AsyncValue.data(WalletState(
        balance: balance,
        recent: _transactions.take(10).toList(),
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);
