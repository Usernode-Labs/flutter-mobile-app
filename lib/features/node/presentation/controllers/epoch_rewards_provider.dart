import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/rewards/data/epoch_rewards_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'node_status_provider.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Unified epoch rewards state combining raw data and UI state
class EpochRewardsState {
  // Raw backend data
  final RpcEpochRewardsResp? rawData;

  // UI state with caching
  final EpochRewardsSnapshot? snapshot;
  final bool isCached;
  final bool isStale;

  const EpochRewardsState({
    required this.rawData,
    required this.snapshot,
    required this.isCached,
    required this.isStale,
  });

  // Convenience getters for direct raw data access
  int? get epoch => rawData?.epoch;
  BigInt? get earnedSoFar => rawData?.earnedSoFar;
  BigInt? get expectedTotal => rawData?.expectedTotal;
  int? get producedInEpoch => rawData?.producedInEpoch;
  int? get winsInEpoch => rawData?.winsInEpoch;
  BigInt? get rewardPerBlock => rawData?.rewardPerBlock;
  List<RpcEpochWonSlot> get wonSlots => rawData?.wonSlots ?? const [];
}

/// Unified epoch rewards controller
class EpochRewardsController extends AsyncNotifier<EpochRewardsState?> {
  BigInt? _previousEarnedSoFar;
  static const String _cacheKey = 'default';

  @override
  Future<EpochRewardsState?> build() async {
    // Depend on status to get epoch value
    final statusAsync = ref.watch(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;

    final cache = EpochRewardsCacheRepository();

    // Step 1: Load cache immediately to show previous data (only on initial build)
    LoggingService.instance.debug('Loading cached epoch rewards...');
    final cached = await cache.getCached(_cacheKey);

    // Step 2: Return cache if available (avoids empty UI while loading)
    if (cached != null) {
      _log.trace(
        'Loaded cached data: epoch=${cached.epoch}, earnedSoFar=${cached.earnedSoFar}',
      );

      // Immediately return cached data (no raw data yet)
      state = AsyncData(EpochRewardsState(
        rawData: null,
        snapshot: cached,
        isCached: true,
        isStale: false,
      ));
    }

    // Step 3: Fetch live data in background
    if (epoch == null) return state.value;
    return await _load(epoch);
  }

  Future<void> refresh() async {
    final statusAsync = ref.read(nodeStatusProvider);
    final epoch = statusAsync.value?.epoch;

    if (epoch == null) {
      state = const AsyncData(null);
      return;
    }

    state = await AsyncValue.guard(() => _load(epoch));
  }

  Future<EpochRewardsState?> _load(int epoch) async {
    try {
      LoggingService.instance
          .debug('Fetching live epoch rewards for epoch $epoch...');

      final rewards =
          await RustBackendService.instance.epochRewards(epoch: epoch);

      if (rewards == null) {
        LoggingService.instance.warn('epochRewards returned null');
        // Return current state if live fetch failed
        return state.value;
      }

      _log.trace(
        'Received live data: epoch=${rewards.epoch}, earnedSoFar=${rewards.earnedSoFar}, expectedTotal=${rewards.expectedTotal}',
      );

      // Create snapshot for caching
      final snapshot = EpochRewardsSnapshot(
        epoch: rewards.epoch,
        earnedSoFar: rewards.earnedSoFar.toString(),
        expectedTotal: rewards.expectedTotal.toString(),
        producedInEpoch: rewards.producedInEpoch,
        winsInEpoch: rewards.winsInEpoch,
        rewardPerBlock: rewards.rewardPerBlock.toString(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        wonSlots: rewards.wonSlots,
      );

      _log.trace(
        'Created snapshot: earnedSoFar=${snapshot.earnedSoFar}, expectedTotal=${snapshot.expectedTotal}',
      );

      // Save to cache
      try {
        final cache = EpochRewardsCacheRepository();
        await cache.save(_cacheKey, snapshot);
        LoggingService.instance.trace('Saved epoch rewards to cache');
      } catch (e, st) {
        _log.error('Failed to save epoch rewards to cache',
            error: e, stackTrace: st);
      }

      // Check if rewards increased and trigger notification
      _checkAndNotifyRewardIncrease(rewards.earnedSoFar, rewards.epoch);

      // Return unified state with both raw data and snapshot
      return EpochRewardsState(
        rawData: rewards,
        snapshot: snapshot,
        isCached: false,
        isStale: false,
      );
    } catch (e, st) {
      _log.error('Failed to load epoch rewards', error: e, stackTrace: st);
      rethrow;
    }
  }

  void _checkAndNotifyRewardIncrease(BigInt earnedSoFar, int epoch) {
    if (_previousEarnedSoFar != null && earnedSoFar > _previousEarnedSoFar!) {
      final diff = earnedSoFar - _previousEarnedSoFar!;
      LoggingService.instance.trace('Reward increased by $diff TKN');
    }
    _previousEarnedSoFar = earnedSoFar;
  }
}

final epochRewardsProvider =
    AsyncNotifierProvider<EpochRewardsController, EpochRewardsState?>(
  EpochRewardsController.new,
);
