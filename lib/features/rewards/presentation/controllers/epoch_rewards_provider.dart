import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/rewards/data/epoch_rewards_cache_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';

final epochRewardsCacheRepoProvider = Provider((ref) => EpochRewardsCacheRepository());

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
  @override
  Future<EpochRewardsUiState?> build() async {
    final repo = ref.read(epochRewardsCacheRepoProvider);
    final envKey = AppConfig.instance.environment;

    // 1) Return cached snapshot immediately if available
    final cached = await repo.getCached(envKey);
    EpochRewardsUiState? initial;
    if (cached != null) {
      final isStale = _isStale(cached.updatedAt);
      initial = EpochRewardsUiState(snapshot: cached, isCached: true, isStale: isStale);
    }

    // 2) Trigger live fetch in background; update state + cache when ready
    Future(() async {
      final live = await RustBackendService.instance.epochRewards();
      if (live != null) {
        final snapshot = EpochRewardsSnapshot(
          epoch: live.epoch,
          earnedSoFar: live.earnedSoFar.toString(),
          expectedTotal: live.expectedTotal.toString(),
          producedInEpoch: live.producedInEpoch,
          winsInEpoch: live.winsInEpoch,
          rewardPerBlock: live.rewardPerBlock.toString(),
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        );
        await repo.save(envKey, snapshot);
        state = AsyncData(EpochRewardsUiState(
          snapshot: snapshot,
          isCached: false,
          isStale: false,
        ));
      }
    });

    return initial;
  }

  bool _isStale(String updatedAtIso) {
    try {
      final ts = DateTime.parse(updatedAtIso).toUtc();
      final age = DateTime.now().toUtc().difference(ts);
      return age > const Duration(seconds: 10);
    } catch (_) {
      return true;
    }
  }
}

final epochRewardsUiProvider = AsyncNotifierProvider<EpochRewardsUiController, EpochRewardsUiState?>(
  EpochRewardsUiController.new,
);
