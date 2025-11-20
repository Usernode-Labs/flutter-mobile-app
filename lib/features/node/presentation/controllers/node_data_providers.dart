import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/core/result.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_blockchain.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'node_status_provider.dart';
import 'node_raw_status_provider.dart';

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
          .error('mempool load failed', tag: 'NODE', error: e, stackTrace: st);
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
      LoggingService.instance.error('mempool result failed',
          tag: 'NODE', error: e, stackTrace: st);
      return Err(
          BackendError('Failed to load mempool', cause: e, stackTrace: st));
    }
  },
);

class NodeBlockchainController extends AsyncNotifier<RpcListBlockchainResp?> {
  @override
  Future<RpcListBlockchainResp?> build() async {
    // Depend on status to get epoch and blockProducer
    final statusAsync = ref.watch(nodeStatusProvider);
    final rawStatusAsync = ref.watch(nodeRawStatusProvider);

    final epoch = statusAsync.value?.epoch;
    final blockProducer = rawStatusAsync.value?.blockProducer?.pubKey;

    return await _load(epoch: epoch, blockProducer: blockProducer);
  }

  Future<void> refresh() async {
    final statusAsync = ref.read(nodeStatusProvider);
    final rawStatusAsync = ref.read(nodeRawStatusProvider);

    final epoch = statusAsync.value?.epoch;
    final blockProducer = rawStatusAsync.value?.blockProducer?.pubKey;

    state = const AsyncLoading();
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
      LoggingService.instance.error('blockchain load failed',
          tag: 'NODE', error: e, stackTrace: st);
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
    final statusAsync = ref.watch(nodeStatusProvider);
    final rawStatusAsync = ref.watch(nodeRawStatusProvider);

    final epoch = statusAsync.value?.epoch;
    final blockProducer = rawStatusAsync.value?.blockProducer?.pubKey;

    final resp = await RustBackendService.instance.listBlockchain(
      limit: 20,
      fromTip: true,
      epoch: epoch,
      blockProducer: blockProducer,
    );
    return Ok(resp);
  } catch (e, st) {
    LoggingService.instance.error('blockchain result failed',
        tag: 'NODE', error: e, stackTrace: st);
    return Err(
        BackendError('Failed to load blockchain', cause: e, stackTrace: st));
  }
});

class NodeEpochRewardsController extends AsyncNotifier<RpcEpochRewardsResp?> {
  @override
  Future<RpcEpochRewardsResp?> build() async {
    // Depend on status to get epoch value
    final statusAsync = ref.watch(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;
    if (epoch == null) return null;

    return await _load(epoch);
  }

  Future<void> refresh() async {
    final statusAsync = ref.read(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;
    state = const AsyncLoading();
    if (epoch == null) {
      state = const AsyncData(null);
      return;
    }
    state = await AsyncValue.guard(() => _load(epoch));
  }

  Future<RpcEpochRewardsResp?> _load(int epoch) async {
    try {
      final rewards =
          await RustBackendService.instance.epochRewards(epoch: epoch);

      // Monitor slots and trigger notifications
      if (rewards != null) {
        await _monitorSlots(rewards, epoch);
      }

      return rewards;
    } catch (e, st) {
      LoggingService.instance.error('epochRewards load failed',
          tag: 'NODE', error: e, stackTrace: st);
      throw BackendError('Failed to load epoch rewards',
          cause: e, stackTrace: st);
    }
  }

  Future<void> _monitorSlots(RpcEpochRewardsResp rewards, int epoch) async {
    // Notification monitoring removed
  }
}

final nodeEpochRewardsProvider =
    AsyncNotifierProvider<NodeEpochRewardsController, RpcEpochRewardsResp?>(
  NodeEpochRewardsController.new,
);

final nodeEpochRewardsResultProvider =
    FutureProvider<Result<RpcEpochRewardsResp?>>((ref) async {
  try {
    final statusAsync = ref.watch(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;
    if (epoch == null) return const Ok(null);
    final resp = await RustBackendService.instance.epochRewards(epoch: epoch);
    return Ok(resp);
  } catch (e, st) {
    LoggingService.instance.error('epoch rewards result failed',
        tag: 'NODE', error: e, stackTrace: st);
    return Err(
        BackendError('Failed to load epoch rewards', cause: e, stackTrace: st));
  }
});
