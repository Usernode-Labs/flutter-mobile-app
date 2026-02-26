import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';

class EventPointsController
    extends AsyncNotifier<CachedData<EventPointsResult>?> {
  @override
  Future<CachedData<EventPointsResult>?> build() async {
    final participantId = await ref.watch(participantIdProvider.future);
    if (participantId == null) return null;

    final ctx = ref.watch(seasonEventContextProvider);
    if (ctx.seasonId == null || ctx.eventId == null) return null;

    // Step 1: Load cache -> render instantly
    final cached = await LeaderboardCache.read<EventPointsResult>(
      type: 'event_points',
      seasonId: ctx.seasonId,
      eventId: ctx.eventId,
      fromJson: (json) =>
          EventPointsResult.fromJson(json as Map<String, dynamic>),
    );
    if (cached != null) {
      state = AsyncData(CachedData(
        data: cached.data,
        isCached: true,
        lastUpdated: cached.updatedAt,
      ));
    }

    // Step 2: Fetch live -> replace
    return _fetchLive(participantId, ctx);
  }

  Future<CachedData<EventPointsResult>?> _fetchLive(
    int participantId,
    SeasonEventContext ctx,
  ) async {
    try {
      final service = ref.read(leaderboardApiServiceProvider);
      final result = await service.getEventPoints(
        eventId: ctx.eventId!,
        participantId: participantId,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await LeaderboardCache.write(
        type: 'event_points',
        seasonId: ctx.seasonId,
        eventId: ctx.eventId,
        toJson: () => result.toJson(),
      );
      return CachedData(data: result, isCached: false, lastUpdated: now);
    } catch (e) {
      if (state.value != null) return state.value;
      rethrow;
    }
  }

  Future<void> silentRefresh() async {
    final participantId = await ref.read(participantIdProvider.future);
    if (participantId == null) return;
    final ctx = ref.read(seasonEventContextProvider);
    if (ctx.seasonId == null || ctx.eventId == null) return;

    final result = await _fetchLive(participantId, ctx);
    if (result != null) state = AsyncData(result);
  }

  Future<void> refresh() async => silentRefresh();
}

final eventPointsProvider = AsyncNotifierProvider<EventPointsController,
    CachedData<EventPointsResult>?>(
  EventPointsController.new,
);
