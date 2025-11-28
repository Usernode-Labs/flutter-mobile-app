import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;

final _log = LoggingService.instance.withTag(LogTag.wallet);

/// Controller that fetches pending transactions from mempool
class WalletMempoolController extends AsyncNotifier<List<MempoolTxSummary>> {
  @override
  Future<List<MempoolTxSummary>> build() async {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<MempoolTxSummary>> _fetch() async {
    try {
      // Get active account address
      String? ownerStr;
      try {
        final repo = await AccountsRepository.create();
        final acc = await repo.getActive();
        if (acc != null &&
            acc.address.isNotEmpty &&
            acc.address.startsWith('ut')) {
          ownerStr = acc.address;
        }
      } catch (e) {
        _log.warn('Failed to get active account: $e');
      }

      if (ownerStr == null) {
        _log.warn('No active account, skipping mempool fetch');
        return const [];
      }

      final owner = rust_types.publicKeyHashFromString(s: ownerStr);

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

final walletMempoolProvider =
    AsyncNotifierProvider<WalletMempoolController, List<MempoolTxSummary>>(
  WalletMempoolController.new,
);
