import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/core/errors/app_error.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Unified node status state combining raw status, sync status, and best tip
class NodeStatusState {
  // Raw status data
  final List<RpcPeerInfo> peers;
  final RpcStatusBlockInfo? localBest;
  final RpcStatusBlockInfo? networkBest;
  final BlockProgressData? fetchProgress;
  final BlockProgressData? applyProgress;
  final RpcStatusBlockProducer? blockProducer;
  final RpcStatusVrfEvaluator? vrfEvaluator;
  final RpcStatusNode node;
  final int slotsInEpoch;
  final int blockInterval;

  // Derived data
  final String? peerId;
  final SyncStatus syncStatus;

  const NodeStatusState({
    required this.peers,
    required this.localBest,
    required this.networkBest,
    required this.fetchProgress,
    required this.applyProgress,
    required this.blockProducer,
    required this.vrfEvaluator,
    required this.node,
    required this.slotsInEpoch,
    required this.blockInterval,
    required this.peerId,
    required this.syncStatus,
  });

  // Convenience getters from NodeRawStatusView
  int? get localBestHeight => localBest?.height;
  int? get networkBestHeight => networkBest?.height;
  int? get epoch => (networkBest ?? localBest)?.epoch;
  int? get globalSlot => (networkBest ?? localBest)?.globalSlot;
  int? get currentEpoch => node.curEpoch;
  int? get currentGlobalSlot => node.curGlobalSlot;

  int? get epochUpperBound {
    final details = vrfEvaluator?.details;
    if (details == null) return null;
    return details.status.whenOrNull(
      readyToEvaluate: (_, __, ___, epochUpperBound, ____, _____) =>
          epochUpperBound,
    );
  }

  int? get epochStartSlot {
    final upperBound = epochUpperBound;
    if (upperBound == null) return null;
    return upperBound - slotsInEpoch + 1;
  }

  String? get bestTipHash {
    try {
      return (networkBest ?? localBest)?.hash.toString();
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

  BigInt? get appliedBlocksCount => applyProgress?.done;

  BigInt? get totalBlocksToApply {
    if (applyProgress == null) return null;
    return applyProgress!.done + applyProgress!.pending + applyProgress!.idle;
  }

  double? get applyProgressPercentage {
    final total = totalBlocksToApply;
    final applied = appliedBlocksCount;
    if (total == null || applied == null || total == BigInt.zero) return null;
    return applied.toDouble() / total.toDouble();
  }

  // === Timing Getters (derived from blockInterval and slotsInEpoch) ===

  /// Slot duration in milliseconds
  int get slotDurationMs => blockInterval;

  /// How far in advance to schedule alarms (12 slots)
  Duration get alarmAdvanceTime => Duration(milliseconds: blockInterval * 12);

  /// Poll interval (1 slot)
  Duration get pollInterval => Duration(milliseconds: blockInterval);

  /// Monitoring timeout (24 slots)
  Duration get monitoringTimeout => Duration(milliseconds: blockInterval * 24);

  /// Monitoring window (36 slots)
  Duration get monitoringWindow => Duration(milliseconds: blockInterval * 36);

  /// Epoch duration
  Duration get epochDuration =>
      Duration(milliseconds: blockInterval * slotsInEpoch);

  /// Slots per minute
  int get slotsPerMinute => 60000 ~/ blockInterval;

  /// Slots per hour
  int get slotsPerHour => 3600000 ~/ blockInterval;

  /// Listener auto-cancel timeout (24 slots)
  Duration get listenerAutoCancel => Duration(milliseconds: blockInterval * 24);

  /// Convert slots to Duration
  Duration slotsToTimer(int slots) => Duration(milliseconds: blockInterval * slots);

  /// Convert Duration to slots
  int durationToSlots(Duration duration) => duration.inMilliseconds ~/ blockInterval;

  /// Dynamic epoch check interval based on progress
  static Duration getEpochCheckInterval(double epochProgress) {
    if (epochProgress < 0.25) return const Duration(minutes: 30);
    if (epochProgress < 0.75) return const Duration(minutes: 15);
    return const Duration(minutes: 5);
  }

  /// Default epoch check interval (static, no state needed)
  static Duration get epochCheckIntervalDefault => const Duration(minutes: 15);
}

class BlockProgressData {
  final BigInt idle;
  final BigInt pending;
  final BigInt done;
  const BlockProgressData({
    required this.idle,
    required this.pending,
    required this.done,
  });
}

/// Unified node status controller
class NodeStatusController extends AsyncNotifier<NodeStatusState?> {
  @override
  Future<NodeStatusState?> build() async {
    return await _load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<NodeStatusState?> _load() async {
    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) return null;

      // Log VRF response for debugging
      final vrf = status.vrfEvaluator;
      if (vrf != null) {
        final vrfJson = {
          'statusTimeMs': vrf.statusTimeMs.toString(),
          'evaluatedSlotsSinceStart': vrf.evaluatedSlotsSinceStart,
          'currentEpochVrfEvaluationStatus': vrf.currentEpochVrfEvaluationStatus.name,
          'nextEpochVrfEvaluationStatus': vrf.nextEpochVrfEvaluationStatus.name,
          'details': vrf.details != null ? {
            'status': vrf.details!.status.toString(),
            'lastEvaluatedEpoch': vrf.details!.lastEvaluatedEpoch,
            'latestEvaluatedGlobalSlot': vrf.details!.latestEvaluatedGlobalSlot,
            'readinessCheckDue': vrf.details!.readinessCheckDue,
            'wonSlotsCached': vrf.details!.wonSlotsCached.toString(),
            'wonSlotsCurrentEpoch': vrf.details!.wonSlotsCurrentEpoch.toString(),
            'wonSlotsNextEpoch': vrf.details!.wonSlotsNextEpoch.toString(),
            'slotsPerEpoch': vrf.details!.slotsPerEpoch,
            'clockEpoch': vrf.details!.clockEpoch,
            'evaluatedCurrentEpoch': vrf.details!.evaluatedCurrentEpoch,
            'evaluatedNextEpoch': vrf.details!.evaluatedNextEpoch,
          } : null,
        };
        _log.debug('VRF response: ${jsonEncode(vrfJson)}');
      }

      // Extract raw status data
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

      // Get peer ID
      final peerId = RustBackendService.instance.getPeerId();

      // Create intermediate state for sync status calculation
      final intermediateState = NodeStatusState(
        peers: status.peers,
        localBest: localBest,
        networkBest: networkBest,
        fetchProgress: fetchProgress,
        applyProgress: applyProgress,
        blockProducer: status.blockProducer,
        vrfEvaluator: status.vrfEvaluator,
        node: status.node,
        slotsInEpoch: status.node.slotsInEpoch,
        blockInterval: status.node.blockInterval,
        peerId: peerId,
        syncStatus: SyncStatus.connecting(), // temporary
      );

      // Calculate sync status
      final syncStatus = _calculateSyncStatus(intermediateState);

      // Return final state with calculated sync status
      return NodeStatusState(
        peers: status.peers,
        localBest: localBest,
        networkBest: networkBest,
        fetchProgress: fetchProgress,
        applyProgress: applyProgress,
        blockProducer: status.blockProducer,
        vrfEvaluator: status.vrfEvaluator,
        node: status.node,
        slotsInEpoch: status.node.slotsInEpoch,
        blockInterval: status.node.blockInterval,
        peerId: peerId,
        syncStatus: syncStatus,
      );
    } catch (e, st) {
      _log.error(
        'status load failed',
        error: e,
        stackTrace: st,
      );
      throw BackendError('Failed to load node status',
          cause: e, stackTrace: st);
    }
  }

  SyncStatus _calculateSyncStatus(NodeStatusState state) {
    // Handle null case
    final connectedPeers = state.connectedPeers;
    if (connectedPeers == 0 || state.peers.isEmpty) {
      _log.trace(
        'No peers connected - status: CONNECTING',
      );
      return SyncStatus.connecting();
    }

    // Gather heights
    final localHeight = state.localBestHeight;
    final networkSyncHeight = state.networkBestHeight;

    if (localHeight == null) {
      _log.warn(
        'No local height available - returning error state',
      );
      return SyncStatus.error(message: 'No local blockchain data');
    }

    // Calculate highest peer height
    int? highestPeerHeight;
    try {
      final peerHeights = state.peers
          .where((p) => p.bestTipHeight != null)
          .map((p) => p.bestTipHeight!)
          .toList();

      if (peerHeights.isNotEmpty) {
        highestPeerHeight = peerHeights.reduce((a, b) => a > b ? a : b);
      }
    } catch (e) {
      _log.warn(
        'Error extracting peer heights: $e',
      );
    }

    // Determine network height
    int? networkHeight;
    if (networkSyncHeight != null || highestPeerHeight != null) {
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
      _log.trace(
        'No network height data available - status: CONNECTING',
      );
      return SyncStatus.connecting();
    }

    // Special case - genesis block
    if (localHeight <= 1 && networkHeight! <= 1) {
      _log.trace(
        'At genesis block (height <= 1) - status: CONNECTING',
      );
      return SyncStatus.connecting();
    }

    // Extract applied blocks data
    final appliedBlocks = state.appliedBlocksCount;
    final targetBlocks = state.totalBlocksToApply;

    final confirmedNetworkHeight = networkHeight!;

    // Determine sync status
    bool synced;
    if (appliedBlocks == null || targetBlocks == null) {
      synced = localHeight >= confirmedNetworkHeight;
    } else {
      synced = appliedBlocks >= targetBlocks;
    }

    _log.trace(
      'Sync status calculated: '
      'local=$localHeight, '
      'networkSync=$networkSyncHeight, '
      'highestPeer=$highestPeerHeight, '
      'network=$confirmedNetworkHeight, '
      'appliedBlocks=$appliedBlocks, '
      'targetBlocks=$targetBlocks, '
      'synced=$synced, '
      'peers=$connectedPeers',
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
  }
}

final nodeStatusProvider =
    AsyncNotifierProvider<NodeStatusController, NodeStatusState?>(
  NodeStatusController.new,
);
