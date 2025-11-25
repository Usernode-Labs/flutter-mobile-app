import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/profile/domain/entities/user_tier.dart';
import 'package:crypto_mobile_app/features/profile/domain/services/points_calculator.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';

/// User tier provider that calculates tier/points/multiplier for current and next epoch
///
/// Currently uses mock data. Will be replaced with backend RPC when available.
class UserTierController extends Notifier<UserTierState> {
  @override
  UserTierState build() {
    // Watch epoch rewards to reactively update when blocks are produced
    final rewardsAsync = ref.watch(epochRewardsProvider);

    // Extract data from rewards (if available)
    final blocksProduced = rewardsAsync.value?.snapshot != null
        ? (rewardsAsync.value!.snapshot!.producedInEpoch as int? ?? 0)
        : 0;

    final winsInEpoch = rewardsAsync.value?.snapshot != null
        ? (rewardsAsync.value!.snapshot!.winsInEpoch as int? ?? 0)
        : 0;

    // TODO: Get identity verification status from account
    // For now, use mock data
    final isIdentityVerified = false;

    // TODO: Get locked tokens from backend
    final lockedTokens = 0;

    // TODO: Get referrals from backend
    final referrals = 0;

    // Calculate current points
    final currentPoints = PointsCalculator.calculatePoints(
      blocksProduced: blocksProduced,
      isIdentityVerified: isIdentityVerified,
      lockedTokens: lockedTokens,
      referrals: referrals,
    );

    final currentTier = TierLevel.fromPoints(currentPoints);

    // Project next epoch points
    // Assume we'll produce same number of blocks as we've won slots
    final expectedBlocksNextEpoch = winsInEpoch;

    final nextEpochPoints = PointsCalculator.projectNextEpochPoints(
      currentPoints: currentPoints,
      expectedBlocksNextEpoch: expectedBlocksNextEpoch,
    );

    final nextEpochTier = TierLevel.fromPoints(nextEpochPoints);

    return UserTierState(
      currentTier: currentTier,
      currentPoints: currentPoints,
      currentMultiplier: currentTier.slotMultiplier,
      nextEpochTier: nextEpochTier,
      nextEpochPoints: nextEpochPoints,
      nextEpochMultiplier: nextEpochTier.slotMultiplier,
    );
  }

  /// Manually refresh tier state (useful after account changes)
  void refresh() {
    ref.invalidateSelf();
  }
}

final userTierProvider = NotifierProvider<UserTierController, UserTierState>(
  UserTierController.new,
);

/// Helper provider to get identity verification status
/// TODO: Implement actual identity verification check
final identityVerifiedProvider = FutureProvider<bool>((ref) async {
  try {
    final repo = await AccountsRepository.create();
    final account = await repo.getActive();
    return account?.identityVerified ?? false;
  } catch (_) {
    return false;
  }
});
