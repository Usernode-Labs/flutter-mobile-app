import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/core/result.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'node_status_provider.dart';

class NodeMempoolController extends AsyncNotifier<RpcListMempoolResp?> {
  @override
  Future<RpcListMempoolResp?> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<RpcListMempoolResp?> _load() async {
    try {
      return await RustBackendService.instance.listMempool();
    } catch (e, st) {
      Log.e('NODE', 'mempool load failed', e, st);
      throw BackendError('Failed to load mempool', cause: e, stackTrace: st);
    }
  }
}

final nodeMempoolProvider =
    AsyncNotifierProvider<NodeMempoolController, RpcListMempoolResp?>(
  NodeMempoolController.new,
);

// Result variants (optional parallel providers for uniform error propagation)
final nodeMempoolResultProvider = FutureProvider<Result<RpcListMempoolResp?>>(
  (ref) async {
    try {
      final resp = await RustBackendService.instance.listMempool();
      return Ok(resp);
    } catch (e, st) {
      Log.e('NODE', 'mempool result failed', e, st);
      return Err(BackendError('Failed to load mempool', cause: e, stackTrace: st));
    }
  },
);

class NodeBlockchainController extends AsyncNotifier<RpcListBlockchainResp?> {
  @override
  Future<RpcListBlockchainResp?> build() async {
    return _load();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<RpcListBlockchainResp?> _load() async {
    try {
      return await RustBackendService.instance
          .listBlockchain(limit: 20, fromTip: true);
    } catch (e, st) {
      Log.e('NODE', 'blockchain load failed', e, st);
      throw BackendError('Failed to load blockchain', cause: e, stackTrace: st);
    }
  }
}

final nodeBlockchainProvider =
    AsyncNotifierProvider<NodeBlockchainController, RpcListBlockchainResp?>(
  NodeBlockchainController.new,
);

final nodeBlockchainResultProvider =
    FutureProvider<Result<RpcListBlockchainResp?>>((ref) async {
  try {
    final resp = await RustBackendService.instance
        .listBlockchain(limit: 20, fromTip: true);
    return Ok(resp);
  } catch (e, st) {
    Log.e('NODE', 'blockchain result failed', e, st);
    return Err(BackendError('Failed to load blockchain', cause: e, stackTrace: st));
  }
});

class NodeEpochRewardsController extends AsyncNotifier<RpcEpochRewardsResp?> {
  @override
  Future<RpcEpochRewardsResp?> build() async {
    // Depend on status to get epoch value
    final status = await ref.watch(nodeStatusProvider.future);
    final epoch = status?.epoch;
    if (epoch == null) return null;
    return _load(epoch);
  }

  Future<void> refresh() async {
    final status = await ref.read(nodeStatusProvider.future);
    final epoch = status?.epoch;
    state = const AsyncLoading();
    if (epoch == null) {
      state = const AsyncData(null);
      return;
    }
    state = await AsyncValue.guard(() => _load(epoch));
  }

  Future<RpcEpochRewardsResp?> _load(int epoch) async {
    try {
      return await RustBackendService.instance.epochRewards(epoch: epoch);
    } catch (e, st) {
      Log.e('NODE', 'epochRewards load failed', e, st);
      throw BackendError('Failed to load epoch rewards',
          cause: e, stackTrace: st);
    }
  }
}

final nodeEpochRewardsProvider =
    AsyncNotifierProvider<NodeEpochRewardsController, RpcEpochRewardsResp?>(
  NodeEpochRewardsController.new,
);

final nodeEpochRewardsResultProvider =
    FutureProvider<Result<RpcEpochRewardsResp?>>((ref) async {
  try {
    final status = await ref.watch(nodeStatusProvider.future);
    final epoch = status?.epoch;
    if (epoch == null) return const Ok(null);
    final resp = await RustBackendService.instance.epochRewards(epoch: epoch);
    return Ok(resp);
  } catch (e, st) {
    Log.e('NODE', 'epoch rewards result failed', e, st);
    return Err(BackendError('Failed to load epoch rewards', cause: e, stackTrace: st));
  }
});
