import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/controllers/utxo_provider.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/token_registry.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

/// Represents an aggregated asset summary across all UTXOs
class AssetSummary {
  final String tokenId;
  final String tokenName;
  final String tokenSymbol;
  final BigInt totalBalance;
  final double usdValue;
  final double change24h;

  const AssetSummary({
    required this.tokenId,
    required this.tokenName,
    required this.tokenSymbol,
    required this.totalBalance,
    required this.usdValue,
    required this.change24h,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetSummary &&
          runtimeType == other.runtimeType &&
          tokenId == other.tokenId &&
          tokenName == other.tokenName &&
          tokenSymbol == other.tokenSymbol &&
          totalBalance == other.totalBalance &&
          usdValue == other.usdValue &&
          change24h == other.change24h;

  @override
  int get hashCode =>
      tokenId.hashCode ^
      tokenName.hashCode ^
      tokenSymbol.hashCode ^
      totalBalance.hashCode ^
      usdValue.hashCode ^
      change24h.hashCode;

  @override
  String toString() =>
      'AssetSummary(tokenId: $tokenId, name: $tokenName, symbol: $tokenSymbol, balance: $totalBalance)';
}

/// Controller that aggregates assets from UTXOs by token_id
class WalletAssetsController extends AsyncNotifier<List<AssetSummary>> {
  @override
  Future<List<AssetSummary>> build() async {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<AssetSummary>> _fetch() async {
    try {
      // Get UTXOs from existing provider
      final utxos = await ref.watch(walletUtxosProvider.future);
      Log.d('ASSETS', 'Aggregating assets from ${utxos.length} UTXOs');

      // Aggregate assets by token_id
      final Map<String, BigInt> balancesByToken = {};

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
            Log.d('ASSETS', '  UTXO[$i]: No assets');
            continue;
          }

          Log.d('ASSETS', '  UTXO[$i]: ${assetsJson.length} assets');

          // Aggregate balances by token_id
          for (final assetJson in assetsJson) {
            final tokenId = assetJson['token_id'] as String;
            final balance = BigInt.from(assetJson['balance'] as int);

            balancesByToken[tokenId] = (balancesByToken[tokenId] ?? BigInt.zero) + balance;
            Log.d('ASSETS', '    Asset: tokenId=$tokenId, balance=$balance');
          }
        } catch (e) {
          Log.w('ASSETS', 'Failed to parse UTXO[$i]: $e');
        }
      }

      Log.d('ASSETS', 'Aggregated ${balancesByToken.length} unique tokens');

      // Convert to AssetSummary list
      final assetSummaries = balancesByToken.entries.map((entry) {
        final tokenIdStr = entry.key;
        final balance = entry.value;

        // Get token metadata
        final metadata = _getTokenMetadata(tokenIdStr);

        return AssetSummary(
          tokenId: tokenIdStr,
          tokenName: metadata['name'] as String,
          tokenSymbol: metadata['symbol'] as String,
          totalBalance: balance,
          usdValue: _calculateUsdValue(tokenIdStr, balance),
          change24h: _getPrice24hChange(tokenIdStr),
        );
      }).toList();

      // Sort by USD value descending
      assetSummaries.sort((a, b) => b.usdValue.compareTo(a.usdValue));

      return assetSummaries;
    } catch (e, st) {
      Log.e('ASSETS', 'Failed to aggregate assets', e, st);
      rethrow;
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

  /// Calculate USD value for a token balance
  /// TODO: Integrate with price oracle/API
  double _calculateUsdValue(String tokenId, BigInt balance) {
    // Mock price data for now
    // TODO: Replace with actual price feed integration
    final mockPrices = {
      'default': 1.50,
      '0x0000000000000000000000000000000000000000000000000000000000000000':
          1.50,
    };

    final pricePerToken = mockPrices[tokenId] ?? 0.0;
    final balanceAsDouble = balance.toDouble();

    return balanceAsDouble * pricePerToken;
  }

  /// Get 24h price change percentage for a token
  /// TODO: Integrate with price oracle/API
  double _getPrice24hChange(String tokenId) {
    // Mock change data for now
    // TODO: Replace with actual price feed integration
    final mockChanges = {
      'default': 2.5,
      '0x0000000000000000000000000000000000000000000000000000000000000000': 2.5,
    };

    return mockChanges[tokenId] ?? 0.0;
  }
}

final walletAssetsProvider =
    AsyncNotifierProvider<WalletAssetsController, List<AssetSummary>>(
  WalletAssetsController.new,
);
