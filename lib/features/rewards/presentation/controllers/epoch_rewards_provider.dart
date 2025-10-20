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

  @override
  Future<EpochRewardsUiState?> build() async {
    // Skip cache loading - fetch only live data
    LoggingService.instance
        .debug('Fetching epoch rewards...', tag: 'EPOCH_REWARDS_UI');
    final live = await RustBackendService.instance.epochRewards();
    if (live == null) {
      LoggingService.instance
          .warn('epochRewards returned null', tag: 'EPOCH_REWARDS_UI');
      return null;
    }

    LoggingService.instance.debug(
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

    LoggingService.instance.debug(
        'Created snapshot: earnedSoFar=${snapshot.earnedSoFar}, expectedTotal=${snapshot.expectedTotal}',
        tag: 'EPOCH_REWARDS_UI');

    // Check if rewards increased and trigger notification
    _checkAndNotifyRewardIncrease(live.earnedSoFar, live.epoch);

    return EpochRewardsUiState(
      snapshot: snapshot,
      isCached: false,
      isStale: false,
    );
  }

  void _checkAndNotifyRewardIncrease(BigInt earnedSoFar, int epoch) {
    if (_previousEarnedSoFar != null && earnedSoFar > _previousEarnedSoFar!) {
      final diff = earnedSoFar - _previousEarnedSoFar!;
      LoggingService.instance.debug(
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
