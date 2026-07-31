import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/identity/wallet_identity_lease.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;

final _log = LoggingService.instance.withTag('usernode/MempoolProvider');

/// Controller that fetches pending transactions from mempool
class WalletMempoolController extends AutoDisposeFamilyAsyncNotifier<
    List<MempoolTxSummary>, WalletRuntimeLease> {
  @override
  Future<List<MempoolTxSummary>> build(WalletRuntimeLease scope) =>
      _fetch(scope);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<List<MempoolTxSummary>> _fetch(WalletRuntimeLease scope) async {
    try {
      if (!RustBackendService.instance.isWalletRuntimeLeaseCurrent(scope)) {
        _log.debug('Wallet scope is no longer current; skipping mempool fetch');
        return const [];
      }

      final owner = rust_types.publicKeyHashFromString(
        s: scope.accountScope.address,
      );

      final resp = await RustBackendService.instance.listMempool(
        owner: owner,
        limit: 100, // Limit to 100 pending transactions
        idsOnly: false,
      );

      final items = resp?.entries ?? const <MempoolTxSummary>[];

      return items;
    } catch (e, st) {
      _log.error('listMempool failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final walletMempoolProvider = AsyncNotifierProvider.autoDispose.family<
    WalletMempoolController, List<MempoolTxSummary>, WalletRuntimeLease>(
  WalletMempoolController.new,
);
