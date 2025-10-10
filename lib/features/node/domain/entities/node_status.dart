// Minimal domain representation of node status for UI consumption.

class NodeStatus {
  final int connectedPeers;
  final int totalPeers;
  final int? localBestHeight;
  final int? networkBestHeight;
  final int? epoch;
  final int? globalSlot;
  final String? bestTipHash;

  const NodeStatus({
    required this.connectedPeers,
    required this.totalPeers,
    required this.localBestHeight,
    required this.networkBestHeight,
    required this.epoch,
    required this.globalSlot,
    required this.bestTipHash,
  });
}

