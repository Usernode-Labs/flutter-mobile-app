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
    Log.d('EPOCH_REWARDS_UI', 'Fetching epoch rewards...');
    final live = await RustBackendService.instance.epochRewards();
    if (live == null) {
      Log.w('EPOCH_REWARDS_UI', 'epochRewards returned null');
      return null;
    }

    Log.d('EPOCH_REWARDS_UI', 'Received live data: epoch=${live.epoch}, earnedSoFar=${live.earnedSoFar}, expectedTotal=${live.expectedTotal}');

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

    Log.d('EPOCH_REWARDS_UI', 'Created snapshot: earnedSoFar=${snapshot.earnedSoFar}, expectedTotal=${snapshot.expectedTotal}');

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
      Log.d('EPOCH_REWARDS_UI', 'Reward increased by $diff TKN, sending notification');

      // Get notifications controller and add notification
      try {
        final notificationsController = ref.read(notificationsProvider.notifier);
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
        Log.e('EPOCH_REWARDS_UI', 'Failed to send notification', e, st);
      }
    }
    _previousEarnedSoFar = earnedSoFar;
  }
}

final epochRewardsUiProvider = AsyncNotifierProvider<EpochRewardsUiController, EpochRewardsUiState?>(
  EpochRewardsUiController.new,
);
