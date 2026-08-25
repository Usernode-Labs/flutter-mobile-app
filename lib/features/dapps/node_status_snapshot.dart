Map<String, dynamic> dappNodeStatusSnapshot({
  required String status,
  required String? chain,
  required int? localBestHeight,
  required int? localBestTimestampMs,
  required int? networkBestHeight,
  required int? readyPeers,
  required int? totalPeers,
  required bool? syncStalled,
  required int? clockDriftMs,
  required bool? walletDataHydrating,
}) {
  return {
    'status': status,
    'chain': chain,
    'localBestHeight': localBestHeight,
    'localBestTimestampMs': localBestTimestampMs,
    'networkBestHeight': networkBestHeight,
    'readyPeers': readyPeers,
    // Retained for older Social Vibecoding builds.
    'connectedPeers': readyPeers,
    'totalPeers': totalPeers,
    'syncStalled': syncStalled,
    'clockDriftMs': clockDriftMs,
    'walletDataHydrating': walletDataHydrating,
  };
}
