import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class BlockProgressData {
  final BigInt idle;
  final BigInt pending;
  final BigInt done;
  const BlockProgressData({required this.idle, required this.pending, required this.done});
}

class NodeRawStatusView {
  final List<RpcPeerInfo> peers;
  final RpcStatusBlockInfo? localBest;
  final RpcStatusBlockInfo? networkBest;
  final BlockProgressData? fetchProgress;
  final BlockProgressData? applyProgress;

  const NodeRawStatusView({
    required this.peers,
    required this.localBest,
    required this.networkBest,
    required this.fetchProgress,
    required this.applyProgress,
  });

  int? get localBestHeight => localBest?.height;
  int? get networkBestHeight => networkBest?.height;
  int? get epoch => (networkBest ?? localBest)?.epoch;
  int? get globalSlot => (networkBest ?? localBest)?.globalSlot;
  String? get bestTipHash {
    try {
      final h = (networkBest ?? localBest)?.hash.toString();
      return h;
    } catch (_) {
      return null;
    }
  }

  List<BigInt> get bestTipBatchTransactions {
    try {
      final bt = (networkBest ?? localBest);
      if (bt == null) return const [];
      return bt.batches.map((b) => b.transactions).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  int get connectedPeers {
    int connected = 0;
    for (final p in peers) {
      if (p.connectionStatus == PeerConnectionStatus.connected) {
        connected++;
      }
    }
    return connected;
  }

  int get totalPeers => peers.length;
}

class NodeRawStatusController extends AsyncNotifier<NodeRawStatusView?> {
  @override
  Future<NodeRawStatusView?> build() async {
    return await _load();
  }

  Future<void> refresh() async {
    // Skip loading state during refresh to keep previous values visible
    state = await AsyncValue.guard(_load);
  }

  Future<NodeRawStatusView?> _load() async {
    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) return null;

      RpcStatusBlockInfo? localBest;
      RpcStatusBlockInfo? networkBest;
      try {
        localBest = status.blockchain.bestTip;
      } catch (_) {
        localBest = null;
      }
      try {
        networkBest = status.blockchain.sync.blocks?.bestTip;
      } catch (_) {
        networkBest = null;
      }

      BlockProgressData? fetchProgress;
      BlockProgressData? applyProgress;
      try {
        final blocks = status.blockchain.sync.blocks;
        if (blocks != null) {
          fetchProgress = BlockProgressData(
            idle: blocks.fetchProgress.idle,
            pending: blocks.fetchProgress.pending,
            done: blocks.fetchProgress.done,
          );
          applyProgress = BlockProgressData(
            idle: blocks.applyProgress.idle,
            pending: blocks.applyProgress.pending,
            done: blocks.applyProgress.done,
          );
        }
      } catch (_) {
        // ignore
      }

      return NodeRawStatusView(
        peers: status.peers,
        localBest: localBest,
        networkBest: networkBest,
        fetchProgress: fetchProgress,
        applyProgress: applyProgress,
      );
    } catch (e, st) {
      Log.e('NODE', 'raw status load failed', e, st);
      throw BackendError('Failed to load node status', cause: e, stackTrace: st);
    }
  }
}

final nodeRawStatusProvider =
    AsyncNotifierProvider<NodeRawStatusController, NodeRawStatusView?>(
  NodeRawStatusController.new,
);

