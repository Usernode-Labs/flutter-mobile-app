import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'node_status_provider.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

class NodeMempoolController extends AsyncNotifier<RpcListMempoolResp?> {
  @override
  Future<RpcListMempoolResp?> build() async {
    return await _load();
  }

  Future<void> refresh() async {
    // Skip loading state during refresh to keep previous values visible
    state = await AsyncValue.guard(_load);
  }

  Future<RpcListMempoolResp?> _load() async {
    try {
      return await RustBackendService.instance.listMempool();
    } catch (e, st) {
      LoggingService.instance
          .error('mempool load failed', error: e, stackTrace: st);
      throw BackendError('Failed to load mempool', cause: e, stackTrace: st);
    }
  }
}

final nodeMempoolProvider =
    AsyncNotifierProvider<NodeMempoolController, RpcListMempoolResp?>(
  NodeMempoolController.new,
);

class NodeBlockchainController extends AsyncNotifier<RpcListBlockchainResp?> {
  @override
  Future<RpcListBlockchainResp?> build() async {
    // Depend on status to get epoch and blockProducer
    final statusAsync = ref.watch(nodeStatusProvider);

    final status = statusAsync.value;
    final epoch = status?.epoch;
    final blockProducer = status?.blockProducer?.pubKey;

    return await _load(epoch: epoch, blockProducer: blockProducer);
  }

  Future<void> refresh() async {
    final statusAsync = ref.read(nodeStatusProvider);

    final status = statusAsync.value;
    final epoch = status?.epoch;
    final blockProducer = status?.blockProducer?.pubKey;

    state = await AsyncValue.guard(
        () => _load(epoch: epoch, blockProducer: blockProducer));
  }

  Future<RpcListBlockchainResp?> _load(
      {int? epoch, AccountPublicKey? blockProducer}) async {
    try {
      return await RustBackendService.instance.listBlockchain(
        limit: 20,
        fromTip: true,
        epoch: epoch,
        blockProducer: blockProducer,
      );
    } catch (e, st) {
      _log.error('blockchain load failed', error: e, stackTrace: st);
      throw BackendError('Failed to load blockchain', cause: e, stackTrace: st);
    }
  }
}

final nodeBlockchainProvider =
    AsyncNotifierProvider<NodeBlockchainController, RpcListBlockchainResp?>(
  NodeBlockchainController.new,
);
