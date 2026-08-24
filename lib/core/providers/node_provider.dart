import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag('usernode/NodeProvider');

/// Unified node status state combining raw status, sync status, and best tip
class NodeStatusState {
  // Raw status data
  final List<RpcPeerInfo> peers;
  final RpcStatusBlockInfo? localBest;
  final RpcStatusBlockInfo? networkBest;
  final BlockProgressData? fetchProgress;
  final BlockProgressData? applyProgress;
  final RpcStatusWalletUtxoSeed? walletUtxoSeed;
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
    required this.walletUtxoSeed,
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

  /// Get chain ID directly from node status
  String? get chainId => node.chainId.toString();

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
  int get slotsPerMinute => blockInterval > 0 ? 60000 ~/ blockInterval : 0;

  /// Slots per hour
  int get slotsPerHour => blockInterval > 0 ? 3600000 ~/ blockInterval : 0;

  /// Listener auto-cancel timeout (24 slots)
  Duration get listenerAutoCancel => Duration(milliseconds: blockInterval * 24);

  /// Convert slots to Duration
  Duration slotsToTimer(int slots) =>
      Duration(milliseconds: blockInterval * slots);

  /// Convert Duration to slots
  int durationToSlots(Duration duration) =>
      blockInterval > 0 ? duration.inMilliseconds ~/ blockInterval : 0;

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
  /// Cadence for automatic background refresh.
  ///
  /// `nodeStatusProvider` used to be a one-shot AsyncNotifier — `build()`
  /// ran once on first read and the result was cached for the lifetime
  /// of the container, with the only refresh path being a manual pull-
  /// to-refresh in Settings. That meant if the *first* read happened
  /// before the embedded Rust node had finished booting (which is the
  /// common case at cold start, because some background tick reads the
  /// provider within seconds of `main()`), the cached state was `null`
  /// for the rest of the session. Every consumer (sync icon, wallet
  /// pill, slot timing, *and* the metrics collector) saw stale state
  /// until the user happened to land on Settings.
  ///
  /// A periodic timer kept here makes the provider self-healing: as
  /// soon as the Rust node becomes reachable, the next tick picks up
  /// fresh status and the whole UI catches up. `getStatus()` is one FFI
  /// hop + one in-process RPC, so the overhead is negligible and a tight
  /// 1s interval keeps the UI close to real-time.
  static const _autoRefreshInterval = Duration(seconds: 1);

  @override
  Future<NodeStatusState?> build() async {
    final timer = Timer.periodic(_autoRefreshInterval, (_) {
      // Skip if a refresh is already in flight; periodic ticks should not
      // pile up if the underlying RPC is slow or wedged.
      if (state.isLoading) return;
      // Fire-and-forget; the AsyncNotifier swallows errors via
      // `AsyncValue.guard` and surfaces them through `state.hasError`.
      silentRefresh();
    });
    ref.onDispose(timer.cancel);
    return await _load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  /// Silent refresh - same as refresh for node provider (already doesn't show loading)
  Future<void> silentRefresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<NodeStatusState?> _load() async {
    final stopwatch = Stopwatch()..start();
    _log.debug('NodeStatusProvider: load start');

    try {
      final status = await RustBackendService.instance.getStatus();
      if (status == null) return null;

      // Fetch block producer status (includes VRF evaluator)
      final bpStatus =
          await RustBackendService.instance.getBlockProducerStatus();

      // Log VRF response for debugging
      final vrf = bpStatus?.vrfEvaluator;
      if (vrf != null) {
        final vrfJson = {
          'statusTimeMs': vrf.statusTimeMs.toString(),
          'evaluatedSlotsSinceStart': vrf.evaluatedSlotsSinceStart,
          'currentEpochVrfEvaluationStatus':
              vrf.currentEpochVrfEvaluationStatus.name,
          'nextEpochVrfEvaluationStatus': vrf.nextEpochVrfEvaluationStatus.name,
          'details': vrf.details != null
              ? {
                  'status': vrf.details!.status.toString(),
                  'lastEvaluatedEpoch': vrf.details!.lastEvaluatedEpoch,
                  'latestEvaluatedGlobalSlot':
                      vrf.details!.latestEvaluatedGlobalSlot,
                  'readinessCheckDue': vrf.details!.readinessCheckDue,
                  'wonSlotsCached': vrf.details!.wonSlotsCached.toString(),
                  'wonSlotsCurrentEpoch':
                      vrf.details!.wonSlotsCurrentEpoch.toString(),
                  'wonSlotsNextEpoch':
                      vrf.details!.wonSlotsNextEpoch.toString(),
                  'slotsPerEpoch': vrf.details!.slotsPerEpoch,
                  'clockEpoch': vrf.details!.clockEpoch,
                  'evaluatedCurrentEpoch': vrf.details!.evaluatedCurrentEpoch,
                  'evaluatedNextEpoch': vrf.details!.evaluatedNextEpoch,
                }
              : null,
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
        walletUtxoSeed: status.blockchain.sync.walletUtxoSeed,
        blockProducer: bpStatus?.blockProducer,
        vrfEvaluator: bpStatus?.vrfEvaluator,
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
        walletUtxoSeed: status.blockchain.sync.walletUtxoSeed,
        blockProducer: bpStatus?.blockProducer,
        vrfEvaluator: bpStatus?.vrfEvaluator,
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
      throw Exception('Failed to load node status $e');
    } finally {
      stopwatch.stop();
      _log.debug(
        'NodeStatusProvider: load completed in ${stopwatch.elapsedMilliseconds} ms',
      );
    }
  }

  SyncStatus _calculateSyncStatus(NodeStatusState state) {
    final connectedPeers = state.connectedPeers;

    // Step 1: No connected peers -> Connecting
    if (connectedPeers == 0) {
      _log.debug('No connected peers - status: CONNECTING');
      return SyncStatus.connecting();
    }

    // Step 2: Get block apply data
    final localHeight = state.localBestHeight ?? 0;
    final appliedBlocks = state.appliedBlocksCount;
    final targetBlocks = state.totalBlocksToApply;

    // Calculate network height for informational purposes
    int? highestPeerHeight;
    final peerHeights = state.peers
        .where((p) => p.bestTipHeight != null)
        .map((p) => p.bestTipHeight!)
        .toList();
    if (peerHeights.isNotEmpty) {
      highestPeerHeight = peerHeights.reduce((a, b) => a > b ? a : b);
    }
    final networkHeight =
        highestPeerHeight ?? state.networkBestHeight ?? localHeight;

    // Step 3: Check sync status based on applied blocks or peer connectivity
    bool synced = false;
    if (appliedBlocks != null &&
        targetBlocks != null &&
        targetBlocks > BigInt.zero) {
      // Apply block data available - use normal comparison
      synced = appliedBlocks >= targetBlocks;
    } else if (connectedPeers > 0) {
      // No apply block data but have connected peers - consider synced
      synced = true;
    }

    _log.trace(
      'Sync: connectedPeers=$connectedPeers, '
      'applied=$appliedBlocks, target=$targetBlocks, synced=$synced',
    );

    // Step 4: Return Synced or Syncing based only on apply progress
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
  }
}

final nodeStatusProvider =
    AsyncNotifierProvider<NodeStatusController, NodeStatusState?>(
  NodeStatusController.new,
);
