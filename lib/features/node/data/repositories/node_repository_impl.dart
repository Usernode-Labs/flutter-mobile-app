import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import '../../domain/entities/node_status.dart' as domain;
import '../../domain/repositories/node_repository.dart';
import 'package:crypto_mobile_app/core/result.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';

class NodeRepositoryImpl implements NodeRepository {
  NodeRepositoryImpl._();
  static NodeRepositoryImpl? _instance;
  static NodeRepositoryImpl get instance =>
      _instance ??= NodeRepositoryImpl._();

  @override
  Future<void> init() async {
    try {
      await RustBackendService.instance.init();
    } catch (e) {
      // Swallow to avoid crashing; Sentry is already handled inside service
    }
  }

  @override
  Future<bool> startNode() async {
    try {
      return await RustBackendService.instance.startNode();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Result<domain.NodeStatus?>> getStatus() async {
    try {
      final s = await RustBackendService.instance.getStatus();
      if (s == null) return const Ok(null);

      // Derive a minimal domain status view
      int connected = 0;
      final peers = s.peers;
      for (final p in peers) {
        if (p.connectionStatus == PeerConnectionStatus.connected) connected++;
      }

      RpcStatusBlockInfo? localBest;
      RpcStatusBlockInfo? networkBest;
      try {
        localBest = s.blockchain.bestTip;
      } catch (_) {
        localBest = null;
      }
      try {
        networkBest = s.blockchain.sync.blocks?.bestTip;
      } catch (_) {
        networkBest = null;
      }
      final display = networkBest ?? localBest;

      String? bestTipHash;
      try {
        bestTipHash = display?.hash.toString();
      } catch (_) {
        bestTipHash = null;
      }

      return Ok(domain.NodeStatus(
        connectedPeers: connected,
        totalPeers: peers.length,
        localBestHeight: localBest?.height,
        networkBestHeight: networkBest?.height,
        epoch: display?.epoch,
        globalSlot: display?.globalSlot,
        currentEpoch: s.node.curEpoch,
        currentGlobalSlot: s.node.curGlobalSlot,
        bestTipHash: bestTipHash,
      ));
    } catch (e) {
      return Err(BackendError('Failed to load node status', cause: e));
    }
  }
}
