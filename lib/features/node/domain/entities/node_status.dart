// Minimal domain representation of node status for UI consumption.

class NodeStatus {
  final int connectedPeers;
  final int totalPeers;
  final int? localBestHeight;
  final int? networkBestHeight;
  final int? epoch;
  final int? globalSlot;
  final int? currentEpoch;
  final int? currentGlobalSlot;
  final String? bestTipHash;
  final String? peerId;

  const NodeStatus({
    required this.connectedPeers,
    required this.totalPeers,
    required this.localBestHeight,
    required this.networkBestHeight,
    required this.epoch,
    required this.globalSlot,
    required this.currentEpoch,
    required this.currentGlobalSlot,
    required this.bestTipHash,
    this.peerId,
  });
}
