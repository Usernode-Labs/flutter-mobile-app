import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_item.dart'
    as transaction_item;
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/mempool_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('usernode/WalletProvider');

class WalletState {
  final WalletBalance balance;
  final List<TransactionModel> recent;

  const WalletState({required this.balance, required this.recent});
}

class WalletController extends AsyncNotifier<WalletState> {
  // Transaction list parsed from UTXOs
  List<TransactionModel> _transactions = [];

  @override
  Future<WalletState> build() async {
    final balance = await _calculateBalance();
    final allTransactions = await _getAllTransactions();
    return WalletState(
      balance: balance,
      recent: allTransactions.take(10).toList(),
    );
  }

  /// Calculate wallet balance using explorer APIs with fallback to UTXOs
  Future<WalletBalance> _calculateBalance() async {
    try {
      // Get active account
      final accountsRepo = await AccountsRepository.create();
      final activeAccount = await accountsRepo.getActive();

      if (activeAccount == null || activeAccount.address.isEmpty) {
        _log.debug('No active account available for balance calculation');
        throw Exception(
            'No active account found. Please create or select an account.');
      }

      final userAddress = activeAccount.address;
      _log.debug('Calculating balance for address: $userAddress');

      // Try explorer APIs first (primary -> secondary -> cached)
      final explorerBalance = await _tryExplorerBalance(userAddress);
      if (explorerBalance != null) {
        return explorerBalance;
      }

      // Fallback to UTXO-based calculation
      _log.debug('Falling back to UTXO-based balance calculation');
      return await _calculateBalanceFromUtxos(userAddress);
    } catch (e, st) {
      _log.error('Failed to calculate wallet balance',
          error: e, stackTrace: st);
      // Return fallback balance
      return WalletBalance(
        tokenAmount: 0.0,
        tokenSymbol: 'TOKENS',
        usdValue: 0.0,
        totalBalance: BigInt.zero,
        dataSource: DataSource.local,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Try to get balance from explorer APIs (primary -> secondary -> cached)
  Future<WalletBalance?> _tryExplorerBalance(String userAddress) async {
    final explorerService = ExplorerService(ref);

    // Try live explorer APIs
    final explorerResponse =
        await explorerService.getAccountBalance(userAddress);
    if (explorerResponse != null) {
      _log.debug(
          'Got balance from explorer API: ${explorerResponse.dataSource}');
      return WalletBalance.fromExplorerBalance(explorerResponse);
    }

    // Try cached data
    final cachedResponse = await explorerService.getCachedBalance(userAddress);
    if (cachedResponse != null) {
      _log.debug('Using cached explorer balance');
      return WalletBalance.fromExplorerBalance(cachedResponse);
    }

    _log.debug('No explorer balance data available');
    return null;
  }

  /// Calculate balance from UTXOs (original implementation)
  Future<WalletBalance> _calculateBalanceFromUtxos(String userAddress) async {
    // Get active account for owner
    final owner = frb_types.publicKeyHashFromString(s: userAddress);
    final utxosResp =
        await RustBackendService.instance.listUtxosByOwner(owner: owner);
    final utxos = utxosResp?.items ?? [];

    _log.debug('Got ${utxos.length} UTXOs for fallback balance calculation');

    // Aggregate balances by token_id
    final Map<String, BigInt> balancesByToken = {};

    // Extract asset data from UTXOs via JSON serialization
    for (var i = 0; i < utxos.length; i++) {
      try {
        final ownedUtxo = utxos[i];
        final jsonStr = frb_types.utxoToJson(utxo: ownedUtxo.utxo);
        final utxoData = json.decode(jsonStr) as Map<String, dynamic>;
        final assetsJson = utxoData['assets'] as List<dynamic>?;

        if (assetsJson == null || assetsJson.isEmpty) continue;

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

    // Parse transactions from UTXOs
    final primaryTokenSymbol = balancesByToken.isNotEmpty ? 'TKN' : 'TOKENS';
    _transactions = _parseTransactionsFromUtxos(utxos, primaryTokenSymbol);

    _log.debug('Calculated balance from UTXOs: ${totalBalance.toString()}');

    return WalletBalance(
      tokenAmount: totalBalance.toDouble(),
      tokenSymbol: primaryTokenSymbol,
      usdValue: 0.0,
      totalBalance: totalBalance,
      dataSource: DataSource.local,
      lastUpdated: DateTime.now(),
    );
  }

  /// Parse transactions from UTXOs to populate recent activity
  List<TransactionModel> _parseTransactionsFromUtxos(
      List<dynamic> utxos, String tokenSymbol) {
    final transactions = <TransactionModel>[];

    for (var i = utxos.length - 1; i >= 0; i--) {
      try {
        final ownedUtxo = utxos[i];

        // Serialize UTXO to JSON string
        final jsonStr = frb_types.utxoToJson(utxo: ownedUtxo.utxo);
        final utxoData = json.decode(jsonStr) as Map<String, dynamic>;

        // Extract assets and create transaction for each
        final assetsJson = utxoData['assets'] as List<dynamic>? ?? [];

        for (final assetJson in assetsJson) {
          final balance = assetJson['balance'] as int;

          // Determine if this is a block reward (exactly 20 TKN)
          final isBlockReward = balance == 20;

          // Create a transaction for each UTXO asset
          final transaction = TransactionModel(
            id: utxoData['id']?.toString() ?? 'utxo_$i',
            title: isBlockReward ? 'Block Reward' : 'Received',
            subtitle: isBlockReward ? 'Mining reward' : 'Token transfer',
            amount: balance.toDouble(),
            tokenSymbol: tokenSymbol,
            type: isBlockReward
                ? TransactionType.reward
                : TransactionType.receive,
            status: TransactionStatus.completed,
            timestamp: _parseTimestampFromUtxo(utxoData),
            icon: isBlockReward ? Icons.star : Icons.south_west,
            color: isBlockReward ? Colors.orange : Colors.green,
            dataSource: DataSource.local, // UTXO transactions are local
          );

          transactions.add(transaction);
        }
      } catch (e, st) {
        _log.error('Failed to parse transaction from UTXO[$i]',
            error: e, stackTrace: st);
      }
    }

    // Sort by timestamp (newest first) and limit to 10
    transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final result = transactions.take(10).toList();

    _log.debug(
        'Parsed ${result.length} transactions from ${utxos.length} UTXOs');
    return result;
  }

  /// Parse timestamp from UTXO data, fallback to current time
  DateTime _parseTimestampFromUtxo(Map<String, dynamic> utxoData) {
    try {
      // Try to extract timestamp from UTXO data
      // This depends on the actual structure we see in logs
      final timestampMs = utxoData['timestamp'] as int?;
      if (timestampMs != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestampMs);
      }
    } catch (e) {
      // Fallback to current time if parsing fails
    }
    return DateTime.now().subtract(
        Duration(minutes: (DateTime.now().millisecondsSinceEpoch % 1000)));
  }

  /// Get all transactions (confirmed from explorer/UTXO + pending from mempool) sorted by timestamp
  Future<List<TransactionModel>> _getAllTransactions() async {
    try {
      // Get current user address
      final accountsRepo = await AccountsRepository.create();
      final activeAccount = await accountsRepo.getActive();

      if (activeAccount == null || activeAccount.address.isEmpty) {
        _log.debug('No active account for transaction fetch');
        return _transactions.take(10).toList();
      }

      final userAddress = activeAccount.address;

      // Get confirmed transactions from explorer APIs or UTXO fallback
      final confirmedTransactions =
          await _getConfirmedTransactions(userAddress);

      // Get pending transactions from mempool (always from local)
      final pendingTransactionModels =
          await _getPendingTransactionModels(userAddress);

      // Combine and deduplicate transactions
      final allTransactions = <TransactionModel>[];
      allTransactions.addAll(pendingTransactionModels);
      allTransactions.addAll(confirmedTransactions);

      // Remove duplicates (same transaction ID)
      final uniqueTransactions = <String, TransactionModel>{};
      for (final tx in allTransactions) {
        uniqueTransactions[tx.id] = tx;
      }
      final dedupedTransactions = uniqueTransactions.values.toList();

      // Sort by timestamp (newest first) with pending transactions prioritized
      dedupedTransactions.sort((a, b) {
        // Pending transactions should come first
        if (a.status == TransactionStatus.pending &&
            b.status == TransactionStatus.completed) {
          return -1;
        }
        if (a.status == TransactionStatus.completed &&
            b.status == TransactionStatus.pending) {
          return 1;
        }
        // Same status, sort by timestamp
        return b.timestamp.compareTo(a.timestamp);
      });

      _log.debug(
          'Combined transactions: ${pendingTransactionModels.length} pending + ${confirmedTransactions.length} confirmed (${dedupedTransactions.length} after deduplication)');

      return dedupedTransactions;
    } catch (e, st) {
      _log.error('Failed to get all transactions', error: e, stackTrace: st);
      // Return just local transactions on error
      return _transactions.take(10).toList();
    }
  }

  /// Get confirmed transactions from explorer APIs with UTXO fallback
  Future<List<TransactionModel>> _getConfirmedTransactions(
      String userAddress) async {
    final explorerService = ExplorerService(ref);

    // Try explorer APIs first
    final explorerResponse =
        await explorerService.getAccountTransactions(userAddress);
    if (explorerResponse != null) {
      _log.debug(
          'Got ${explorerResponse.transactions.length} transactions from explorer API: ${explorerResponse.dataSource}');
      return explorerResponse.transactions
          .map((explorerTx) => TransactionModel.fromExplorerTransaction(
              explorerTx, explorerResponse.dataSource, userAddress))
          .toList();
    }

    // Try cached explorer data
    final cachedResponse =
        await explorerService.getCachedTransactions(userAddress);
    if (cachedResponse != null) {
      _log.debug(
          'Using ${cachedResponse.transactions.length} cached explorer transactions');
      return cachedResponse.transactions
          .map((explorerTx) => TransactionModel.fromExplorerTransaction(
              explorerTx, cachedResponse.dataSource, userAddress))
          .toList();
    }

    // Fallback to UTXO-based transactions
    _log.debug('Using UTXO-based transactions as fallback');
    await _ensureUtxoTransactionsLoaded();
    return _transactions;
  }

  /// Get pending transaction models from mempool
  Future<List<TransactionModel>> _getPendingTransactionModels(
      String userAddress) async {
    try {
      // Get pending transactions from mempool
      final mempoolTransactions = await _getPendingTransactions(userAddress);

      // Convert mempool transactions to TransactionModel format
      return mempoolTransactions
          .map((tx) => _convertMempoolToTransactionModel(tx))
          .toList();
    } catch (e, st) {
      _log.error('Failed to get pending transactions',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Get pending transactions from mempool for current user
  Future<List<transaction_item.TransactionItem>> _getPendingTransactions(
      String ownerAddress) async {
    try {
      final mempoolProvider = ref.read(walletMempoolProvider);
      final mempoolSummaries = mempoolProvider.valueOrNull ?? [];

      return mempoolSummaries
          .map((tx) => transaction_item.TransactionItem.fromMempoolTx(
                tx: tx,
                ownerAddress: ownerAddress,
              ))
          .toList();
    } catch (e, st) {
      _log.error('Failed to fetch pending transactions',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Convert TransactionItem (from mempool) to TransactionModel format
  TransactionModel _convertMempoolToTransactionModel(
      transaction_item.TransactionItem txItem) {
    // Determine icon and color based on transaction type
    IconData icon;
    Color color;
    String title;
    String subtitle;
    TransactionType modelType;

    switch (txItem.type) {
      case transaction_item.TransactionType.sent:
        icon = Icons.north_east;
        color = Colors.red;
        title = 'Sending';
        subtitle = 'Transaction pending';
        modelType = TransactionType.send;
        break;
      case transaction_item.TransactionType.received:
        icon = Icons.south_west;
        color = Colors.green;
        title = 'Receiving';
        subtitle = 'Transaction pending';
        modelType = TransactionType.receive;
        break;
      case transaction_item.TransactionType.coinbaseReward:
        icon = Icons.star;
        color = Colors.orange;
        title = 'Mining Reward';
        subtitle = 'Pending confirmation';
        modelType = TransactionType.reward;
        break;
      case transaction_item.TransactionType.genesis:
        icon = Icons.diamond;
        color = Colors.purple;
        title = 'Genesis';
        subtitle = 'Pending confirmation';
        modelType = TransactionType.reward;
        break;
    }

    // Calculate total amount (approximation since we may not have access to full amounts)
    double amount = 0.0;
    if (txItem.amounts.isNotEmpty) {
      amount = txItem.amounts.first.amount.toDouble();
    }

    return TransactionModel(
      id: txItem.id,
      title: title,
      subtitle: subtitle,
      amount: amount,
      tokenSymbol: 'TKN',
      type: modelType,
      status: TransactionStatus.pending,
      timestamp: DateTime.now(), // Use current time for pending transactions
      icon: icon,
      color: color,
      dataSource: DataSource.local, // Mempool transactions are always local
    );
  }

  /// Ensure UTXO transactions are loaded when needed as fallback
  Future<void> _ensureUtxoTransactionsLoaded() async {
    if (_transactions.isNotEmpty) return; // Already loaded
    
    try {
      _log.debug('Loading UTXO transactions for fallback');
      
      // Get active account address for UTXO lookup
      final accountsRepo = await AccountsRepository.create();
      final activeAccount = await accountsRepo.getActive();
      if (activeAccount == null || activeAccount.address.isEmpty) {
        _log.debug('No active account for UTXO fallback');
        return;
      }
      
      final owner = frb_types.publicKeyHashFromString(s: activeAccount.address);
      final utxosResp = await RustBackendService.instance.listUtxosByOwner(owner: owner);
      final utxos = utxosResp?.items ?? [];
      final primaryTokenSymbol = 'TKN';
      _transactions = _parseTransactionsFromUtxos(utxos, primaryTokenSymbol);
      _log.debug('Loaded ${_transactions.length} UTXO transactions for fallback');
    } catch (e, st) {
      _log.error('Failed to load UTXO transactions for fallback', error: e, stackTrace: st);
      _transactions = [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    try {
      // Also refresh the mempool data
      await ref.read(walletMempoolProvider.notifier).refresh();

      final balance = await _calculateBalance();
      final allTransactions = await _getAllTransactions();
      state = AsyncValue.data(WalletState(
        balance: balance,
        recent: allTransactions.take(10).toList(),
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Silent refresh - updates data without showing loading spinner
  Future<void> silentRefresh() async {
    try {
      // Silently refresh mempool data too
      await ref.read(walletMempoolProvider.notifier).refresh();

      final balance = await _calculateBalance();
      final allTransactions = await _getAllTransactions();
      state = AsyncValue.data(WalletState(
        balance: balance,
        recent: allTransactions.take(10).toList(),
      ));
    } catch (e) {
      // Keep existing state on error during silent refresh
      _log.debug('Silent refresh failed: $e');
    }
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);
