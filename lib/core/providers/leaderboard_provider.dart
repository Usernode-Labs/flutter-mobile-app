import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
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

class LeaderboardController extends AsyncNotifier<LeaderboardState?> {
  int _currentPage = 1;

  @override
  Future<LeaderboardState?> build() async {
    _currentPage = 1;
    final ctx = ref.watch(seasonEventContextProvider);

    if (ctx.seasonId == null) return null;

    return _fetchPage1(ctx);
  }

  Future<LeaderboardState?> _fetchPage1(SeasonEventContext ctx) async {
    try {
      final service = ref.read(leaderboardApiServiceProvider);
      final result = await service.getLeaderboard(
        seasonId: ctx.seasonId!,
        eventId: ctx.eventId,
        page: 1,
      );
      _currentPage = 1;
      return LeaderboardState(result: result, allEntries: result.entries);
    } catch (e) {
      if (state.value != null) return state.value;
      rethrow;
    }
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null) return;

    if (current.isLoadingMore) return;

    final pagination = current.result?.pagination;
    if (pagination == null || _currentPage >= pagination.totalPages) return;

    state = AsyncData(
      LeaderboardState(
        result: current.result,
        allEntries: current.allEntries,
        isLoadingMore: true,
      ),
    );

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
      state = AsyncData(
        LeaderboardState(
          result: result,
          allEntries: [...current.allEntries, ...result.entries],
        ),
      );
    } catch (e) {
      _log.warn('Failed to load next page: $e');
      state = AsyncData(
        LeaderboardState(
          result: current.result,
          allEntries: current.allEntries,
        ),
      );
    }
  }

  Future<void> silentRefresh() async {
    final ctx = ref.read(seasonEventContextProvider);
    if (ctx.seasonId == null) return;

    try {
      final result = await _fetchPage1(ctx);
      if (result != null) state = AsyncData(result);
    } catch (e) {
      _log.warn('silentRefresh failed: $e');
    }
  }

  Future<void> refresh() async => silentRefresh();
}

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardController, LeaderboardState?>(
  LeaderboardController.new,
);
