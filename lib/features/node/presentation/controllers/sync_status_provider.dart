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
  int networkHeight = localHeight; // Default to local if no network data

  if (networkSyncHeight != null && highestPeerHeight != null) {
    networkHeight = networkSyncHeight > highestPeerHeight
        ? networkSyncHeight
        : highestPeerHeight;
  } else if (networkSyncHeight != null) {
    networkHeight = networkSyncHeight;
  } else if (highestPeerHeight != null) {
    networkHeight = highestPeerHeight;
  }

  // Step 4.5: If connected but network height is unknown, we're syncing
  // This prevents false "synced" status when we have no network data
  if (connectedPeers > 0 && networkSyncHeight == null && highestPeerHeight == null) {
    LoggingService.instance.trace(
      'Connected to peers but network height unknown - status: SYNCING',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.syncing(
      localHeight: localHeight,
      networkHeight: localHeight, // Use local as placeholder
      connectedPeers: connectedPeers,
      highestPeerHeight: null,
    );
  }

  // Step 5: Special case - genesis block
  // If both local and network are at height 1 or less, we're not truly synced yet
  if (localHeight <= 1 && networkHeight <= 1) {
    LoggingService.instance.trace(
      'At genesis block (height <= 1) - status: SYNCING',
      tag: 'SYNC_STATUS',
    );
    return SyncStatus.syncing(
      localHeight: localHeight,
      networkHeight: networkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
    );
  }

  // Step 6: Extract applied blocks data
  final appliedBlocks = raw.appliedBlocksCount;
  final targetBlocks = raw.totalBlocksToApply;

  // Step 7: Determine sync status
  // If no applyProgress data AND localHeight == networkHeight, consider it synced
  bool synced;
  if (appliedBlocks == null || targetBlocks == null) {
    // No apply progress data - fallback to height comparison
    synced = localHeight >= networkHeight;
  } else {
    // Use apply progress: synced if all blocks are applied
    synced = appliedBlocks >= targetBlocks;
  }

  LoggingService.instance.trace(
    'Sync status calculated: '
    'local=$localHeight, '
    'networkSync=$networkSyncHeight, '
    'highestPeer=$highestPeerHeight, '
    'network=$networkHeight, '
    'appliedBlocks=$appliedBlocks, '
    'targetBlocks=$targetBlocks, '
    'synced=$synced, '
    'peers=$connectedPeers',
    tag: 'SYNC_STATUS',
  );

  if (synced) {
    return SyncStatus.synced(
      localHeight: localHeight,
      networkHeight: networkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  } else {
    return SyncStatus.syncing(
      localHeight: localHeight,
      networkHeight: networkHeight,
      connectedPeers: connectedPeers,
      highestPeerHeight: highestPeerHeight,
      appliedBlocks: appliedBlocks,
      targetBlocks: targetBlocks,
    );
  }
});
