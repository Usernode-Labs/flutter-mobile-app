import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/features/node/domain/entities/sync_status.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final syncStatusProvider = Provider<SyncStatus>((ref) {
  final raw = ref.watch(nodeRawStatusProvider).value;

  // Handle null or error case
  if (raw == null) {
    return SyncStatus.error(message: 'No status data');
  }

  // Step 1: Check peer connectivity
  final connectedPeers = raw.connectedPeers;
  if (connectedPeers == 0) {
    LoggingService.instance.trace(
      'No peers connected - status: CONNECTING',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.connecting();
  }

  // Step 2: Gather heights
  final localHeight = raw.localBestHeight;
  final networkSyncHeight = raw.networkBestHeight;

  // If we don't have local height, we can't determine sync status
  if (localHeight == null) {
    LoggingService.instance.warn(
      'No local height available - returning error state',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.error(message: 'No local blockchain data');
  }

  // Step 3: Calculate highest peer height
  int? highestPeerHeight;
  try {
    final peerHeights = raw.peers
        .where((p) => p.bestTipHeight != null)
        .map((p) => p.bestTipHeight!)
        .toList();

    if (peerHeights.isNotEmpty) {
      highestPeerHeight = peerHeights.reduce((a, b) => a > b ? a : b);
    }
  } catch (e) {
    LoggingService.instance.warn(
      'Error extracting peer heights: $e',
      tag: 'SYNC_STATUS',
    );
  }

  // Step 4: Determine network height
  // Network height is the maximum of:
  // - Network sync height (from blockchain.sync.blocks.best_tip)
  // - Highest peer best tip height
  // If we have no network data from sync OR peers, we can't determine sync status
  int? networkHeight;

  if (networkSyncHeight != null || highestPeerHeight != null) {
    // We have at least one source of network height data
    if (networkSyncHeight != null && highestPeerHeight != null) {
      networkHeight = networkSyncHeight > highestPeerHeight
          ? networkSyncHeight
          : highestPeerHeight;
    } else if (networkSyncHeight != null) {
      networkHeight = networkSyncHeight;
    } else if (highestPeerHeight != null) {
      networkHeight = highestPeerHeight;
    }
  } else {
    // No network height data available - we're still connecting
    LoggingService.instance.trace(
      'No network height data available (networkSync=$networkSyncHeight, highestPeer=$highestPeerHeight) - status: CONNECTING',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.connecting();
  }

  // Step 5: Special case - genesis block
  // If both local and network are at height 1 or less, show connecting
  if (localHeight <= 1 && networkHeight! <= 1) {
    LoggingService.instance.trace(
      'At genesis block (height <= 1) - status: CONNECTING',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.connecting();
  }

  // Step 6: Extract applied blocks data
  final appliedBlocks = raw.appliedBlocksCount;
  final targetBlocks = raw.totalBlocksToApply;

  // At this point, networkHeight is guaranteed to be non-null
  // (we returned early if it was null)
  final confirmedNetworkHeight = networkHeight!;

  // Step 7: Determine sync status
  // If no applyProgress data AND localHeight == networkHeight, consider it synced
  bool synced;
  if (appliedBlocks == null || targetBlocks == null) {
    // No apply progress data - fallback to height comparison
    synced = localHeight >= confirmedNetworkHeight;
  } else {
    // Use apply progress: synced if all blocks are applied
    synced = appliedBlocks >= targetBlocks;
  }

  LoggingService.instance.trace(
    'Sync status calculated: '
    'local=$localHeight, '
    'networkSync=$networkSyncHeight, '
    'highestPeer=$highestPeerHeight, '
    'network=$confirmedNetworkHeight, '
    'appliedBlocks=$appliedBlocks, '
    'targetBlocks=$targetBlocks, '
    'synced=$synced, '
    'peers=$connectedPeers',
    tag: 'SYNC_STATUS',
  );

  if (synced) {
    return SyncStatus.synced(
      localHeight: localHeight,
      networkHeight: confirmedNetworkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  } else {
    return SyncStatus.syncing(
      localHeight: localHeight,
      networkHeight: confirmedNetworkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  }
});
