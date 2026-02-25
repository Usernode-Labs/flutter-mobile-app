import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';

class SeasonsController extends AsyncNotifier<CachedData<List<SeasonDto>>?> {
  @override
  Future<CachedData<List<SeasonDto>>?> build() async {
    // Step 1: Load cache -> render instantly
    final cached = await LeaderboardCache.read<List<SeasonDto>>(
      type: 'seasons',
      fromJson: (json) => (json as List)
          .map((e) => SeasonDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (cached != null) {
      state = AsyncData(CachedData(
        data: cached.data,
        isCached: true,
        lastUpdated: cached.updatedAt,
      ));
    }

    // Step 2: Fetch live -> replace
    return _fetchLive();
  }

  Future<CachedData<List<SeasonDto>>?> _fetchLive() async {
    try {
      final service = ref.read(leaderboardApiServiceProvider);
      final result = await service.getSeasons();
      final now = DateTime.now().toUtc().toIso8601String();
      await LeaderboardCache.write(
        type: 'seasons',
        toJson: () => result.map((s) => s.toJson()).toList(),
      );
      return CachedData(data: result, isCached: false, lastUpdated: now);
    } catch (e) {
      if (state.value != null) return state.value;
      rethrow;
    }
  }

  Future<void> silentRefresh() async {
    final result = await _fetchLive();
    if (result != null) state = AsyncData(result);
  }

  Future<void> refresh() async => silentRefresh();
}

final seasonsProvider =
    AsyncNotifierProvider<SeasonsController, CachedData<List<SeasonDto>>?>(
  SeasonsController.new,
);
