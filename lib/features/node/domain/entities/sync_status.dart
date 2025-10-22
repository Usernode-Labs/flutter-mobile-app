/// Node connection and synchronization state
enum NodeConnectionState {
  /// Node has no peer connections - waiting to connect
  connecting,

  /// Node is connected to peers but blockchain is not fully synced
  syncing,

  /// Node is connected and blockchain is fully synchronized
  synced,

  /// Backend error or failed to get status
  error,
}

/// Represents the synchronization status of the node
class SyncStatus {
  /// Current connection and sync state
  final NodeConnectionState state;

  /// Human-readable status label
  final String label;

  /// Sync progress from 0.0 (0%) to 1.0 (100%)
  final double progress;

  /// Local blockchain height (best tip)
  final int? localHeight;

  /// Network blockchain height (highest known)
  final int? networkHeight;

  /// Number of connected peers
  final int connectedPeers;

  /// Highest best tip height reported by connected peers
  final int? highestPeerHeight;

  /// Number of blocks that have been applied (from applyProgress.done)
  final BigInt? appliedBlocks;

  /// Total number of blocks to apply (from applyProgress total)
  final BigInt? targetBlocks;

  const SyncStatus({
    required this.state,
    required this.label,
    required this.progress,
    this.localHeight,
    this.networkHeight,
    required this.connectedPeers,
    this.highestPeerHeight,
    this.appliedBlocks,
    this.targetBlocks,
  });

  /// Check if node is synchronized
  bool get isSynced => state == NodeConnectionState.synced;

  /// Check if node is connecting
  bool get isConnecting => state == NodeConnectionState.connecting;

  /// Check if node is syncing
  bool get isSyncing => state == NodeConnectionState.syncing;

  /// Check if there's an error
  bool get hasError => state == NodeConnectionState.error;

  /// Get blocks remaining to sync (null if synced or unknown)
  int? get blocksRemaining {
    if (localHeight != null && networkHeight != null && localHeight! < networkHeight!) {
      return networkHeight! - localHeight!;
    }
    return null;
  }

  /// Factory constructor for connecting state (no peers)
  factory SyncStatus.connecting() {
    return const SyncStatus(
      state: NodeConnectionState.connecting,
      label: 'Connecting',
      progress: 0.0,
      connectedPeers: 0,
    );
  }

  /// Factory constructor for syncing state
  factory SyncStatus.syncing({
    required int localHeight,
    required int networkHeight,
    required int connectedPeers,
    int? highestPeerHeight,
    BigInt? appliedBlocks,
    BigInt? targetBlocks,
  }) {
    // Calculate progress based on applied blocks if available
    double progress;
    if (appliedBlocks != null && targetBlocks != null && targetBlocks > BigInt.zero) {
      progress = (appliedBlocks.toDouble() / targetBlocks.toDouble()).clamp(0.0, 1.0);
    } else {
      // Fallback to height-based calculation
      progress = networkHeight > 0 ? (localHeight / networkHeight).clamp(0.0, 1.0) : 0.0;
    }

    final percentage = (progress * 100).toStringAsFixed(1);

    return SyncStatus(
      state: NodeConnectionState.syncing,
      label: 'Syncing ($percentage%)',
      progress: progress,
      localHeight: localHeight,
      networkHeight: networkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  }

  /// Factory constructor for synced state
  factory SyncStatus.synced({
    required int localHeight,
    required int networkHeight,
    required int connectedPeers,
    int? highestPeerHeight,
    BigInt? appliedBlocks,
    BigInt? targetBlocks,
  }) {
    return SyncStatus(
      state: NodeConnectionState.synced,
      label: 'Synced',
      progress: 1.0,
      localHeight: localHeight,
      networkHeight: networkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  }

  /// Factory constructor for error state
  factory SyncStatus.error({String? message}) {
    return SyncStatus(
      state: NodeConnectionState.error,
      label: message ?? 'Error',
      progress: 0.0,
      connectedPeers: 0,
    );
  }

  @override
  String toString() {
    return 'SyncStatus('
        'state: $state, '
        'label: $label, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'local: $localHeight, '
        'network: $networkHeight, '
        'peers: $connectedPeers'
        ')';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatus &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          label == other.label &&
          progress == other.progress &&
          localHeight == other.localHeight &&
          networkHeight == other.networkHeight &&
          connectedPeers == other.connectedPeers &&
          highestPeerHeight == other.highestPeerHeight;

  @override
  int get hashCode =>
      state.hashCode ^
      label.hashCode ^
      progress.hashCode ^
      (localHeight?.hashCode ?? 0) ^
      (networkHeight?.hashCode ?? 0) ^
      connectedPeers.hashCode ^
      (highestPeerHeight?.hashCode ?? 0);
}
