import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';

class WalletUtxosController extends AsyncNotifier<List<OwnedUtxo>> {
  @override
  Future<List<OwnedUtxo>> build() async {
    return _fetch();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<OwnedUtxo>> _fetch() async {
    try {
      // Determine owner from active account if available; fallback to a known test owner.
      const fallbackOwner =
          'ut1na9lq2yny9l2l6axf09g3mhhmhed3vj7tpejs4f28xe2cjd6n5qqg9ww4x';

      String ownerStr = fallbackOwner;
      try {
        final repo = await AccountsRepository.create();
        final acc = await repo.getActive();
        if (acc != null && acc.address.isNotEmpty) {
          // Only use if the format looks like a utxo address ("ut...") that backend expects.
          // Otherwise keep fallback to avoid RPC errors until address formats are unified.
          if (acc.address.startsWith('ut')) {
            ownerStr = acc.address;
          }
        }
      } catch (_) {
        // ignore repository errors and use fallback
      }

      final owner = rust_types.publicKeyHashFromString(s: ownerStr);

      final resp = await RustBackendService.instance.listUtxosByOwner(
        owner: owner,
      );
      final items = resp?.items ?? const <OwnedUtxo>[];
      LoggingService.instance
          .debug('loaded items=${items.length}', tag: 'UTXO');
      return items;
    } catch (e, st) {
      LoggingService.instance.error('listUtxosByOwner failed',
          tag: 'UTXO', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final walletUtxosProvider =
    AsyncNotifierProvider<WalletUtxosController, List<OwnedUtxo>>(
  WalletUtxosController.new,
);
