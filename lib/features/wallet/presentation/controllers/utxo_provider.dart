import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as rust_types;

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
      // TEMP: hardcoded owner until account selection is wired
      const hardcodedOwner =
          'AiitAFAG8P8g6uXXu6zmbzsaa5bFXDNwCMYDkSUyH2wU8XLpNG';
      final owner = rust_types.publicKeyHashFromString(s: hardcodedOwner);
      Log.i(
        'UTXO',
        'GET rpc.listUtxosByOwner params={owner: $hardcodedOwner, limit: null}',
      );
      final resp = await RustBackendService.instance.listUtxosByOwner(
        owner: owner,
      );
      final items = resp?.items ?? const <OwnedUtxo>[];
      Log.d('UTXO', 'loaded items=${items.length}');
      return items;
    } catch (e, st) {
      Log.e('UTXO', 'listUtxosByOwner failed', e, st);
      rethrow;
    }
  }
}

final walletUtxosProvider =
    AsyncNotifierProvider<WalletUtxosController, List<OwnedUtxo>>(
  WalletUtxosController.new,
);
