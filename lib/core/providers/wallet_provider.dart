import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_item.dart'
    as transaction_item;
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/wallet_identity_lease.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/mempool_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('usernode/WalletProvider');

class WalletState {
  final WalletBalance balance;
  final List<TransactionModel> recent;
  final WalletDataScope? scope;

  const WalletState({
    required this.balance,
    required this.recent,
    required this.scope,
  });
}

typedef _WalletLoadScope = ({
  WalletDataScope data,
  WalletRuntimeLease? runtime,
  bool chainObserved,
});

class WalletController extends AsyncNotifier<WalletState> {
  @override
  Future<WalletState> build() async {
    // Balance and history derive from the identity's confirmed address.
    // Rebuild on every identity transition (login, logout, reconcile account
    // switch, season rollover) so user B never sees — or serves to dApps via
    // getWalletState — user A's cached balance and transactions.
    final identity = ref.watch(identityProvider);
    final runtimeStamp = ref.watch(
      nodeStatusProvider.select(
        (status) => (
          chainId: _normalizeChainId(status.valueOrNull?.chainId),
          generation: RustBackendService.instance.runtimeGeneration,
        ),
      ),
    );
    final authority = WalletIdentityLease.capture(identity);
    if (authority == null) {
      // No identity owns a wallet right now (guest, mid-reconcile, boot):
      // an empty wallet, never the registry's active account (it may belong
      // to a previous user).
      return _emptyWalletState();
    }
    var scope = await _walletScopeFor(authority, runtimeStamp.chainId);

    // Preserve the startup fallback without making stable explorer caches
    // depend on a running node. A cached chain resolves immediately; only a
    // first-ever offline load waits once for node status to identify a chain.
    if (scope == null && !RustBackendService.instance.isRunning) {
      await Future.delayed(const Duration(seconds: 2));
      if (!authority.isCurrent) return _emptyWalletState();
      scope = await _walletScopeFor(authority, _currentChainId());
    }
    if (scope == null) return _emptyWalletState();

    var balance = await _calculateBalance(scope);
    var allTransactions = await _getAllTransactions(scope);

    // Startup race guard: wallet can initialize before node/RPC is running.
    // Retry once so initial UI does not get stuck on transient 0 balance.
    if (balance.totalBalance == BigInt.zero &&
        allTransactions.isEmpty &&
        !RustBackendService.instance.isRunning) {
      _log.debug(
          'Initial wallet load happened before node start; retrying once');
      await Future.delayed(const Duration(seconds: 2));
      if (!authority.isCurrent) return _emptyWalletState();
      final retryScope =
          await _walletScopeFor(authority, _currentChainId()) ?? scope;
      scope = retryScope;
      balance = await _calculateBalance(retryScope);
      allTransactions = await _getAllTransactions(retryScope);
    }

    if (!_walletScopeIsCurrent(scope.data)) return _emptyWalletState();

    return WalletState(
      balance: balance,
      recent: allTransactions,
      scope: scope.data,
    );
  }

  /// The account scope whose wallet this provider may expose, or null when
  /// the current identity does not own one. Same policy as the dApp bridge:
  /// [Identity.allowsSigning] — ready, or local-only unauthenticated with
  /// an active account; when it holds, [Identity.address] is non-null.
  Future<_WalletLoadScope?> _walletScopeFor(
    WalletIdentityLease authority,
    String? observedChainId,
  ) async {
    final explorerService = ExplorerService();
    final chainId = await explorerService.resolveChainId(
      scope: authority.accountScope,
      observedChainId: observedChainId,
    );
    explorerService.dispose();
    if (chainId == null) return null;
    final data = WalletDataScope(
      accountScope: authority.accountScope,
      chainId: chainId,
    );
    final runtime = observedChainId == chainId
        ? RustBackendService.instance.captureWalletRuntimeLease(
            authority: authority,
            dataScope: data,
          )
        : null;
    return (
      data: data,
      runtime: runtime,
      chainObserved: observedChainId == chainId,
    );
  }

  static String? _normalizeChainId(String? chainId) {
    final normalized = chainId?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String? _currentChainId() =>
      _normalizeChainId(ref.read(nodeStatusProvider).valueOrNull?.chainId);

  bool _walletScopeIsCurrent(WalletDataScope scope) {
    final currentChainId = _currentChainId();
    return WalletIdentityLease.capture(ref.read(identityProvider))
                ?.accountScope ==
            scope.accountScope &&
        (currentChainId == null || currentChainId == scope.chainId);
  }

  WalletState _emptyWalletState() => WalletState(
        balance: _emptyBalance(),
        recent: const [],
        scope: null,
      );

  WalletBalance _emptyBalance() => WalletBalance(
        tokenAmount: 0.0,
        tokenSymbol: 'TOKENS',
        totalBalance: BigInt.zero,
        dataSource: DataSource.local,
        lastUpdated: DateTime.now(),
      );

  /// Calculate wallet balance using explorer APIs with fallback to UTXOs
  Future<WalletBalance> _calculateBalance(_WalletLoadScope scope) async {
    final userAddress = scope.data.accountScope.address;
    try {
      _log.debug('Calculating balance for address: $userAddress');

      // Try explorer APIs first (primary -> secondary -> cached)
      final explorerBalance = await _tryExplorerBalance(
        scope.data,
        preferCache: !scope.chainObserved,
      );
      if (explorerBalance != null) {
        return explorerBalance;
      }

      // Fallback to node-local wallet data.
      _log.debug('Falling back to local wallet balance calculation');
      final runtime = scope.runtime;
      if (runtime == null) return _emptyBalance();
      return await _calculateBalanceFromLocalWallet(userAddress, runtime) ??
          _emptyBalance();
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
  Future<WalletBalance?> _tryExplorerBalance(
    WalletDataScope scope, {
    required bool preferCache,
  }) async {
    final explorerService = ExplorerService();
    try {
      if (preferCache) {
        final cachedResponse = await explorerService.getCachedBalance(
          scope: scope.accountScope,
          chainId: scope.chainId,
        );
        if (cachedResponse != null) {
          _log.debug('Using cached explorer balance while node is offline');
          return WalletBalance.fromExplorerBalance(cachedResponse);
        }
      }

      // Try live explorer APIs
      final explorerResponse = await explorerService.getAccountBalance(
        scope: scope.accountScope,
        chainId: scope.chainId,
      );
      if (explorerResponse != null) {
        _log.debug(
            'Got balance from explorer API: ${explorerResponse.dataSource}');
        return WalletBalance.fromExplorerBalance(explorerResponse);
      }

      // Try cached data
      if (!preferCache) {
        final cachedResponse = await explorerService.getCachedBalance(
          scope: scope.accountScope,
          chainId: scope.chainId,
        );
        if (cachedResponse != null) {
          _log.debug('Using cached explorer balance');
          return WalletBalance.fromExplorerBalance(cachedResponse);
        }
      }

      _log.debug('No explorer balance data available');
      return null;
    } finally {
      explorerService.dispose();
    }
  }

  /// Calculate balance from local node wallet data.
  Future<WalletBalance?> _calculateBalanceFromLocalWallet(
    String userAddress,
    WalletRuntimeLease runtime,
  ) async {
    if (!RustBackendService.instance.isWalletRuntimeLeaseCurrent(runtime)) {
      return null;
    }
    final owner = frb_types.publicKeyHashFromString(s: userAddress);

    final balanceResp =
        await RustBackendService.instance.walletBalance(owner: owner);
    if (!RustBackendService.instance.isWalletRuntimeLeaseCurrent(runtime)) {
      return null;
    }

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
  Future<List<TransactionModel>> _getAllTransactions(
      _WalletLoadScope scope) async {
    try {
      // Get confirmed transactions from explorer APIs or UTXO fallback
      final confirmedTransactions = await _getConfirmedTransactions(
        scope.data,
        preferCache: !scope.chainObserved,
      );

      // Get pending transactions from mempool (always from local)
      final pendingTransactionModels =
          await _getPendingTransactionModels(scope.runtime);

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
    WalletDataScope scope, {
    required bool preferCache,
  }) async {
    final explorerService = ExplorerService();
    try {
      if (preferCache) {
        final cachedResponse = await explorerService.getCachedTransactions(
          scope: scope.accountScope,
          chainId: scope.chainId,
        );
        if (cachedResponse != null) {
          _log.debug(
            'Using ${cachedResponse.transactions.length} cached explorer '
            'transactions while node is offline',
          );
          return cachedResponse.transactions
              .map((explorerTx) => TransactionModel.fromExplorerTransaction(
                  explorerTx,
                  cachedResponse.dataSource,
                  scope.accountScope.address))
              .toList();
        }
      }

      // Try explorer APIs first
      final explorerResponse = await explorerService.getAccountTransactions(
        scope: scope.accountScope,
        chainId: scope.chainId,
      );
      if (explorerResponse != null) {
        _log.debug(
            'Got ${explorerResponse.transactions.length} transactions from explorer API: ${explorerResponse.dataSource}');
        return explorerResponse.transactions
            .map((explorerTx) => TransactionModel.fromExplorerTransaction(
                explorerTx,
                explorerResponse.dataSource,
                scope.accountScope.address))
            .toList();
      }

      // Try cached explorer data
      if (!preferCache) {
        final cachedResponse = await explorerService.getCachedTransactions(
          scope: scope.accountScope,
          chainId: scope.chainId,
        );
        if (cachedResponse != null) {
          _log.debug(
              'Using ${cachedResponse.transactions.length} cached explorer transactions');
          return cachedResponse.transactions
              .map((explorerTx) => TransactionModel.fromExplorerTransaction(
                  explorerTx,
                  cachedResponse.dataSource,
                  scope.accountScope.address))
              .toList();
        }
      }

      // No explorer data available - return empty list
      _log.debug('No explorer transaction data available');
      return [];
    } finally {
      explorerService.dispose();
    }
  }

  /// Get pending transaction models from mempool
  Future<List<TransactionModel>> _getPendingTransactionModels(
      WalletRuntimeLease? scope) async {
    if (scope == null) return const [];
    try {
      // Get pending transactions from mempool
      final mempoolTransactions = await _getPendingTransactions(scope);

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
      WalletRuntimeLease scope) async {
    try {
      final mempoolSummaries =
          await ref.read(walletMempoolProvider(scope).future);
      if (!RustBackendService.instance.isWalletRuntimeLeaseCurrent(scope)) {
        return const [];
      }

      return mempoolSummaries
          .map((tx) => transaction_item.TransactionItem.fromMempoolTx(
                tx: tx,
                ownerAddress: scope.accountScope.address,
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
    // Manual refreshes bypass build(); apply the same identity gate so a
    // refresh racing a transition can't repopulate the wallet from the
    // registry's (possibly switched) active account.
    final authority = WalletIdentityLease.capture(ref.read(identityProvider));
    if (authority == null) {
      state = AsyncValue.data(_emptyWalletState());
      return;
    }
    state = const AsyncLoading();
    final scope = await _walletScopeFor(authority, _currentChainId());
    if (scope == null) {
      state = AsyncValue.data(_emptyWalletState());
      return;
    }

    try {
      // Also refresh the mempool data
      final runtime = scope.runtime;
      if (runtime != null) {
        await ref.read(walletMempoolProvider(runtime).notifier).refresh();
      }

      final balance = await _calculateBalance(scope);
      final allTransactions = await _getAllTransactions(scope);
      if (!_walletScopeIsCurrent(scope.data)) {
        ref.invalidateSelf();
        return;
      }
      state = AsyncValue.data(WalletState(
        balance: balance,
        recent: allTransactions,
        scope: scope.data,
      ));
    } catch (e, st) {
      if (_walletScopeIsCurrent(scope.data)) {
        state = AsyncValue.error(e, st);
      } else {
        ref.invalidateSelf();
      }
    }
  }

  /// Silent refresh - updates data without showing loading spinner
  Future<void> silentRefresh() async {
    final authority = WalletIdentityLease.capture(ref.read(identityProvider));
    if (authority == null) return;
    final scope = await _walletScopeFor(authority, _currentChainId());
    if (scope == null) {
      return;
    }
    try {
      // Silently refresh mempool data too
      final runtime = scope.runtime;
      if (runtime != null) {
        await ref.read(walletMempoolProvider(runtime).notifier).refresh();
      }

      final balance = await _calculateBalance(scope);
      final allTransactions = await _getAllTransactions(scope);
      if (!_walletScopeIsCurrent(scope.data)) return;
      state = AsyncValue.data(WalletState(
        balance: balance,
        recent: allTransactions,
        scope: scope.data,
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
