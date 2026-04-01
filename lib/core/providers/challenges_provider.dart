import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';

class ChallengesController
    extends AsyncNotifier<CachedData<List<ChallengeDto>>?> {
  @override
  Future<CachedData<List<ChallengeDto>>?> build() async {
    final ctx = ref.watch(seasonEventContextProvider);

    // Step 1: Load cache -> render instantly
    final cached = await LeaderboardCache.read<List<ChallengeDto>>(
      type: 'challenges',
      seasonId: ctx.seasonId,
      eventId: ctx.eventId,
      fromJson: (json) => (json as List)
          .map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
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
    return _fetchLive(ctx);
  }

  Future<CachedData<List<ChallengeDto>>?> _fetchLive(
    SeasonEventContext ctx,
  ) async {
    try {
      final service = ref.read(leaderboardApiServiceProvider);
      var result = await service.getChallenges(
        seasonId: ctx.seasonId,
        eventId: ctx.eventId,
        onlyScheduled: ctx.eventId == null ? true : null,
      );
      // Client-side safety net: when showing all events, drop challenges
      // whose schedule has already ended.
      if (ctx.eventId == null) {
        final now = DateTime.now().toUtc();
        result = result.where((c) {
          if (c.scheduleEnd == null) return true;
          final end = DateTime.tryParse(c.scheduleEnd!);
          return end == null || !now.isAfter(end.toUtc());
        }).toList();
      }
      final now = DateTime.now().toUtc().toIso8601String();
      await LeaderboardCache.write(
        type: 'challenges',
        seasonId: ctx.seasonId,
        eventId: ctx.eventId,
        toJson: () => result.map((c) => c.toJson()).toList(),
      );
      return CachedData(data: result, isCached: false, lastUpdated: now);
    } catch (e) {
      if (state.value != null) return state.value;
      rethrow;
    }
  }

  Future<void> silentRefresh() async {
    final ctx = ref.read(seasonEventContextProvider);

    final result = await _fetchLive(ctx);
    if (result != null) state = AsyncData(result);
  }

  Future<void> refresh() async => silentRefresh();
}

final challengesProvider = AsyncNotifierProvider<ChallengesController,
    CachedData<List<ChallengeDto>>?>(
  ChallengesController.new,
);
