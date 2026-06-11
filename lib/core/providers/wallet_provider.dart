import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

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
  @override
  Future<WalletState> build() async {
    var balance = await _calculateBalance();
    var allTransactions = await _getAllTransactions();

    // Startup race guard: wallet can initialize before node/RPC is running.
    // Retry once so initial UI does not get stuck on transient 0 balance.
    if (balance.totalBalance == BigInt.zero &&
        allTransactions.isEmpty &&
        !RustBackendService.instance.isRunning) {
      _log.debug(
          'Initial wallet load happened before node start; retrying once');
      await Future.delayed(const Duration(seconds: 2));
      balance = await _calculateBalance();
      allTransactions = await _getAllTransactions();
    }

    return WalletState(
      balance: balance,
      recent: allTransactions,
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

      // Fallback to node-local wallet data.
      _log.debug('Falling back to local wallet balance calculation');
      return await _calculateBalanceFromLocalWallet(userAddress);
    } catch (e, st) {
      _log.error('Failed to calculate wallet balance',
          error: e, stackTrace: st);
      // Return fallback balance
      return WalletBalance(
        tokenAmount: 0.0,
        tokenSymbol: 'TOKENS',
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

  /// Calculate balance from local node wallet data.
  Future<WalletBalance> _calculateBalanceFromLocalWallet(
      String userAddress) async {
    final owner = frb_types.publicKeyHashFromString(s: userAddress);

    final balanceResp =
        await RustBackendService.instance.walletBalance(owner: owner);

    _log.debug('Got wallet balance response=${balanceResp != null}');

    final totalBalance = balanceResp?.baseTotal ?? BigInt.zero;

    final primaryTokenSymbol = totalBalance > BigInt.zero ? 'TKN' : 'TOKENS';

    _log.debug('Calculated local wallet balance: ${totalBalance.toString()}');

    return WalletBalance(
      tokenAmount: totalBalance.toDouble(),
      tokenSymbol: primaryTokenSymbol,
      totalBalance: totalBalance,
      dataSource: DataSource.local,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get all transactions (confirmed from explorer + pending from mempool) sorted by timestamp
  Future<List<TransactionModel>> _getAllTransactions() async {
    try {
      // Get current user address
      final accountsRepo = await AccountsRepository.create();
      final activeAccount = await accountsRepo.getActive();

      if (activeAccount == null || activeAccount.address.isEmpty) {
        _log.debug('No active account for transaction fetch');
        return [];
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
      return [];
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

    // No explorer data available - return empty list
    _log.debug('No explorer transaction data available');
    return [];
  }

  /// Get pending transaction models from mempool
  Future<List<TransactionModel>> _getPendingTransactionModels(
      String userAddress) async {
    try {
      // Get pending transactions from mempool
      final mempoolTransactions = await _getPendingTransactions(userAddress);

      // Convert mempool transactions to TransactionModel format
      final transactionModels = <TransactionModel>[];
      for (final tx in mempoolTransactions) {
        final model = _convertMempoolToTransactionModel(tx);
        transactionModels.add(model);
      }
      return transactionModels;
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
    String shortenAddress(String address) {
      if (address.length <= 16) return address;
      return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
    }

    // Determine icon and color based on transaction type
    IconData icon;
    Color color;
    String title;
    String subtitle;
    TransactionType modelType;

    switch (txItem.type) {
      case transaction_item.TransactionType.sent:
        icon = Symbols.north_east_sharp;
        color = Colors.red;
        title = 'Sending';
        subtitle = txItem.recipientAddress != null
            ? 'To: ${shortenAddress(txItem.recipientAddress!)}'
            : 'Transaction pending';
        modelType = TransactionType.send;
        break;
      case transaction_item.TransactionType.received:
        icon = Symbols.south_west_sharp;
        color = Colors.green;
        title = 'Receiving';
        subtitle = 'Transaction pending';
        modelType = TransactionType.receive;
        break;
      case transaction_item.TransactionType.coinbaseReward:
        icon = Symbols.star_sharp;
        color = Colors.orange;
        title = 'Mining Reward';
        subtitle = 'Pending confirmation';
        modelType = TransactionType.reward;
        break;
      case transaction_item.TransactionType.genesis:
        icon = Symbols.diamond_sharp;
        color = Colors.purple;
        title = 'Genesis';
        subtitle = 'Pending confirmation';
        modelType = TransactionType.reward;
        break;
    }

    // Extract pending transaction amount.
    double amount = 0.0;
    if (txItem.asset != null) {
      amount = txItem.asset!.amount.toDouble();
    }

    // Ensure pending "send" amounts are displayed as negative in the UI.
    if (modelType == TransactionType.send) {
      amount = -amount.abs();
    } else {
      amount = amount.abs();
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
      // Outgoing pending tx: the recipient is the dapp/peer we sent to.
      // Incoming pending tx: TransactionItem doesn't carry sender info,
      // so leave null (rare case in practice — receives are usually
      // already confirmed by the time they show up).
      counterpartyAddress:
          modelType == TransactionType.send ? txItem.recipientAddress : null,
    );
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
        recent: allTransactions,
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
        recent: allTransactions,
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
