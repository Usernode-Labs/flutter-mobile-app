import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/core/utils/leaderboard_cache.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardProvider');

class LeaderboardState {
  final LeaderboardResult? result;
  final List<LeaderboardEntry> allEntries;
  final bool isLoadingMore;

  const LeaderboardState({
    this.result,
    this.allEntries = const [],
    this.isLoadingMore = false,
  });
}

class LeaderboardController
    extends AsyncNotifier<CachedData<LeaderboardState>?> {
  int _currentPage = 1;

  @override
  Future<CachedData<LeaderboardState>?> build() async {
    _currentPage = 1;
    final ctx = ref.watch(seasonEventContextProvider);

    if (ctx.seasonId == null) return null;

    // Step 1: Load page-1 cache -> render instantly
    final cached = await LeaderboardCache.read<LeaderboardResult>(
      type: 'leaderboard',
      seasonId: ctx.seasonId,
      eventId: ctx.eventId,
      page: 1,
      fromJson: (json) =>
          LeaderboardResult.fromJson(json as Map<String, dynamic>),
    );
    if (cached != null) {
      state = AsyncData(CachedData(
        data: LeaderboardState(
          result: cached.data,
          allEntries: cached.data.entries,
        ),
        isCached: true,
        lastUpdated: cached.updatedAt,
      ));
    }

    // Step 2: Fetch live page 1 -> replace
    return _fetchPage1(ctx);
  }

  Future<CachedData<LeaderboardState>?> _fetchPage1(
    SeasonEventContext ctx,
  ) async {
    try {
      final service = ref.read(leaderboardApiServiceProvider);
      final result = await service.getLeaderboard(
        seasonId: ctx.seasonId!,
        eventId: ctx.eventId,
        page: 1,
      );
      final now = DateTime.now().toUtc().toIso8601String();
      await LeaderboardCache.write(
        type: 'leaderboard',
        seasonId: ctx.seasonId,
        eventId: ctx.eventId,
        page: 1,
        toJson: () => result.toJson(),
      );
      _currentPage = 1;
      return CachedData(
        data: LeaderboardState(
          result: result,
          allEntries: result.entries,
        ),
        isCached: false,
        lastUpdated: now,
      );
    } catch (e) {
      if (state.value != null) return state.value;
      rethrow;
    }
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null) return;

    final inner = current.data;
    if (inner.isLoadingMore) return;

    final pagination = inner.result?.pagination;
    if (pagination == null || _currentPage >= pagination.totalPages) return;

    state = AsyncData(current.copyWith(
      data: LeaderboardState(
        result: inner.result,
        allEntries: inner.allEntries,
        isLoadingMore: true,
      ),
    ));

    try {
      final ctx = ref.read(seasonEventContextProvider);
      final service = ref.read(leaderboardApiServiceProvider);
      final nextPage = _currentPage + 1;

      final result = await service.getLeaderboard(
        seasonId: ctx.seasonId!,
        eventId: ctx.eventId,
        page: nextPage,
      );

      _currentPage = nextPage;
      state = AsyncData(current.copyWith(
        data: LeaderboardState(
          result: result,
          allEntries: [...inner.allEntries, ...result.entries],
        ),
      ));
    } catch (e) {
      _log.warn('Failed to load next page: $e');
      state = AsyncData(current.copyWith(
        data: LeaderboardState(
          result: inner.result,
          allEntries: inner.allEntries,
        ),
      ));
    }
  }

  Future<void> silentRefresh() async {
    final ctx = ref.read(seasonEventContextProvider);
    if (ctx.seasonId == null) return;

    final result = await _fetchPage1(ctx);
    if (result != null) state = AsyncData(result);
  }

  Future<void> refresh() async => silentRefresh();
}

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardController, CachedData<LeaderboardState>?>(
  LeaderboardController.new,
);
