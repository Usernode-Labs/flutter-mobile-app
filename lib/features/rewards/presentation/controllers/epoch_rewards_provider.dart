import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/rewards/data/epoch_rewards_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/notifications_provider.dart';
import 'package:crypto_mobile_app/core/models/app_notification.dart';

class EpochRewardsUiState {
  final EpochRewardsSnapshot? snapshot;
  final bool isCached;
  final bool isStale;

  const EpochRewardsUiState({
    required this.snapshot,
    required this.isCached,
    required this.isStale,
  });
}

class EpochRewardsUiController extends AsyncNotifier<EpochRewardsUiState?> {
  BigInt? _previousEarnedSoFar;
  static const String _cacheKey = 'default';

  @override
  Future<EpochRewardsUiState?> build() async {
    final cache = EpochRewardsCacheRepository();

    // Step 1: Load cache immediately to show previous data (only on initial build)
    LoggingService.instance
        .debug('Loading cached epoch rewards...', tag: 'EPOCH_REWARDS_UI');
    final cached = await cache.getCached(_cacheKey);

    // Step 2: Return cache if available (avoids empty UI while loading)
    if (cached != null) {
      LoggingService.instance.trace(
          'Loaded cached data: epoch=${cached.epoch}, earnedSoFar=${cached.earnedSoFar}',
          tag: 'EPOCH_REWARDS_UI');

      // Immediately return cached data
      state = AsyncData(EpochRewardsUiState(
        snapshot: cached,
        isCached: true,
        isStale: false,
      ));
    }

    // Step 3: Fetch live data in background
    return await _fetchAndSave();
  }

  /// Refresh method for periodic updates (doesn't reload cache, avoids blinking)
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _fetchAndSave());
  }

  /// Fetches live data and saves to cache
  Future<EpochRewardsUiState?> _fetchAndSave() async {
    LoggingService.instance
        .debug('Fetching live epoch rewards...', tag: 'EPOCH_REWARDS_UI');
    final live = await RustBackendService.instance.epochRewards();
    if (live == null) {
      LoggingService.instance
          .warn('epochRewards returned null', tag: 'EPOCH_REWARDS_UI');
      // Return current state if live fetch failed
      return state.value;
    }

    LoggingService.instance.trace(
        'Received live data: epoch=${live.epoch}, earnedSoFar=${live.earnedSoFar}, expectedTotal=${live.expectedTotal}',
        tag: 'EPOCH_REWARDS_UI');

    final snapshot = EpochRewardsSnapshot(
      epoch: live.epoch,
      earnedSoFar: live.earnedSoFar.toString(),
      expectedTotal: live.expectedTotal.toString(),
      producedInEpoch: live.producedInEpoch,
      winsInEpoch: live.winsInEpoch,
      rewardPerBlock: live.rewardPerBlock.toString(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      wonSlots: live.wonSlots,
    );

    LoggingService.instance.trace(
        'Created snapshot: earnedSoFar=${snapshot.earnedSoFar}, expectedTotal=${snapshot.expectedTotal}',
        tag: 'EPOCH_REWARDS_UI');

    // Save to cache
    try {
      final cache = EpochRewardsCacheRepository();
      await cache.save(_cacheKey, snapshot);
      LoggingService.instance
          .trace('Saved epoch rewards to cache', tag: 'EPOCH_REWARDS_UI');
    } catch (e, st) {
      LoggingService.instance.error('Failed to save epoch rewards to cache',
          tag: 'EPOCH_REWARDS_UI', error: e, stackTrace: st);
    }

    // Check if rewards increased and trigger notification
    _checkAndNotifyRewardIncrease(live.earnedSoFar, live.epoch);

    // Return fresh data
    return EpochRewardsUiState(
      snapshot: snapshot,
      isCached: false,
      isStale: false,
    );
  }

  void _checkAndNotifyRewardIncrease(BigInt earnedSoFar, int epoch) {
    if (_previousEarnedSoFar != null && earnedSoFar > _previousEarnedSoFar!) {
      final diff = earnedSoFar - _previousEarnedSoFar!;
      LoggingService.instance.trace(
          'Reward increased by $diff TKN, sending notification',
          tag: 'EPOCH_REWARDS_UI');

      // Get notifications controller and add notification
      try {
        final notificationsController =
            ref.read(notificationsProvider.notifier);
        notificationsController.addNotification(
          AppNotification.create(
            title: 'Reward Earned',
            message: 'Earned $diff TKN in epoch $epoch',
            type: NotificationType.rewardEarned,
            data: {
              'amount': diff.toString(),
              'epoch': epoch,
              'totalEarned': earnedSoFar.toString(),
            },
          ),
        );
      } catch (e, st) {
        LoggingService.instance.error('Failed to send notification',
            tag: 'EPOCH_REWARDS_UI', error: e, stackTrace: st);
      }
    }
    _previousEarnedSoFar = earnedSoFar;
  }
}

final epochRewardsUiProvider =
    AsyncNotifierProvider<EpochRewardsUiController, EpochRewardsUiState?>(
  EpochRewardsUiController.new,
);
