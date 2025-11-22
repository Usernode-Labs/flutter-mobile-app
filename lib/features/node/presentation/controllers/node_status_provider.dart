import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/node_status.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

/// Derived provider that transforms NodeRawStatusView into the domain NodeStatus entity.
/// This provider no longer makes backend calls - it derives data from nodeRawStatusProvider.
final nodeStatusProvider = Provider<AsyncValue<NodeStatus?>>((ref) {
  final rawAsync = ref.watch(nodeRawStatusProvider);

  return rawAsync.when(
    data: (raw) {
      if (raw == null) return const AsyncData(null);

      // Get peer ID from backend service
      final peerId = RustBackendService.instance.getPeerId();

      return AsyncData(NodeStatus(
        connectedPeers: raw.connectedPeers,
        totalPeers: raw.totalPeers,
        localBestHeight: raw.localBestHeight,
        networkBestHeight: raw.networkBestHeight,
        epoch: raw.epoch,
        globalSlot: raw.globalSlot,
        currentEpoch: raw.currentEpoch,
        currentGlobalSlot: raw.currentGlobalSlot,
        bestTipHash: raw.bestTipHash,
        peerId: peerId,
      ));
    },
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
  );
});
