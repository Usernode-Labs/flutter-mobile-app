import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/models/wallet_balance.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

final _log = LoggingService.instance.withTag('usernode/WalletProvider');

class WalletState {
  final WalletBalance balance;

  const WalletState({required this.balance});
}

class WalletController extends AsyncNotifier<WalletState> {
  @override
  Future<WalletState> build() async {
    // Balance derives from the identity's confirmed address. Rebuild on every
    // identity transition (login, logout, reconcile account switch, season
    // rollover) so user B never sees — or serves to dApps via getWalletState —
    // user A's cached balance.
    final identity = ref.watch(identityProvider);
    final address = _walletAddressFor(identity);
    if (address == null) {
      // No identity owns a wallet right now (guest, mid-reconcile, boot):
      // an empty wallet, never the registry's active account (it may belong
      // to a previous user).
      return WalletState(balance: _emptyBalance());
    }
    var balance = await _calculateBalance(address);

    // Startup race guard: wallet can initialize before node/RPC is running.
    // Retry once so initial UI does not get stuck on transient 0 balance.
    if (balance.totalBalance == BigInt.zero &&
        !RustBackendService.instance.isRunning) {
      _log.debug(
          'Initial wallet load happened before node start; retrying once');
      await Future.delayed(const Duration(seconds: 2));
      balance = await _calculateBalance(address);
    }

    return WalletState(balance: balance);
  }

  /// The address whose wallet this provider may expose, or null when the
  /// current identity does not own one. Same policy as the dApp bridge:
  /// [Identity.allowsSigning] — ready, or local-only unauthenticated with
  /// an active account; when it holds, [Identity.address] is non-null.
  String? _walletAddressFor(Identity identity) {
    if (!identity.allowsSigning) return null;
    return identity.address;
  }

  WalletBalance _emptyBalance() => WalletBalance(
        tokenAmount: 0.0,
        tokenSymbol: 'TOKENS',
        totalBalance: BigInt.zero,
        dataSource: DataSource.local,
        lastUpdated: DateTime.now(),
      );

  /// Calculate wallet balance using explorer APIs with fallback to UTXOs
  Future<WalletBalance> _calculateBalance(String userAddress) async {
    try {
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
      return _emptyBalance();
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
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);
