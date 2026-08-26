import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/wallet/models/wallet_balance.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/wallet.dart';

final _log = LoggingService.instance.withTag('usernode/WalletProvider');

class WalletBalanceUnavailable implements Exception {
  final String reason;

  const WalletBalanceUnavailable(this.reason);

  @override
  String toString() => 'WalletBalanceUnavailable: $reason';
}

WalletBalance walletBalanceFromLocalResponse(RpcWalletBalanceResp? response) {
  if (response == null) {
    throw const WalletBalanceUnavailable('wallet RPC did not return a result');
  }
  if (!response.tracked) {
    throw const WalletBalanceUnavailable('wallet owner is not tracked');
  }

  final totalBalance = response.baseTotal;
  return WalletBalance(
    tokenAmount: totalBalance.toDouble(),
    tokenSymbol: totalBalance > BigInt.zero ? 'TKN' : 'TOKENS',
    totalBalance: totalBalance,
    lastUpdated: DateTime.now(),
  );
}

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

    // Rebuild only when the node-local owner scan becomes ready, not on every
    // one-second node status poll.
    final localWalletReady = ref.watch(
      nodeStatusProvider.select(
        (status) => status.valueOrNull?.walletUtxoSeed?.seeded ?? false,
      ),
    );
    if (!localWalletReady) {
      throw const WalletBalanceUnavailable(
        'local wallet owner scan is not complete',
      );
    }

    final balance = await _calculateBalanceFromLocalWallet(address);
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
        lastUpdated: DateTime.now(),
      );

  /// Calculate balance from local node wallet data.
  Future<WalletBalance> _calculateBalanceFromLocalWallet(
      String userAddress) async {
    final owner = frb_types.publicKeyHashFromString(s: userAddress);

    final balanceResp =
        await RustBackendService.instance.walletBalance(owner: owner);

    _log.debug(
      'Got wallet balance response',
      context: {'tracked': balanceResp?.tracked},
    );

    final balance = walletBalanceFromLocalResponse(balanceResp);
    _log.debug(
      'Calculated local wallet balance: ${balance.totalBalance.toString()}',
    );
    return balance;
  }
}

final walletProvider = AsyncNotifierProvider<WalletController, WalletState>(
  WalletController.new,
);
