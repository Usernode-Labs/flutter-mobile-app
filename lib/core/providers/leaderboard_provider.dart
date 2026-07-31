import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
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

class LeaderboardController extends LeaderboardNotifier<LeaderboardState> {
  int _currentPage = 1;
  int _dataGeneration = 0;

  @override
  bool watchDeps() {
    final ctx = ref.watch(seasonEventContextProvider);
    return ctx.seasonId != null;
  }

  @override
  Future<LeaderboardState> fetch(AuthenticatedUserLease owner) async {
    final generation = ++_dataGeneration;
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    final result = await service.getLeaderboard(
      seasonId: ctx.seasonId!,
      eventId: ctx.eventId,
      page: 1,
      authority: owner.identityLease,
    );
    if (canPublish(owner) && generation == _dataGeneration) {
      _currentPage = 1;
    }
    return LeaderboardState(result: result, allEntries: result.entries);
  }

  Future<void> loadNextPage() async {
    final owner = readReadyOwner();
    if (owner == null) return;

    final current = state.value;
    if (current == null) return;

    if (current.isLoadingMore) return;

    final pagination = current.result?.pagination;
    if (pagination == null || _currentPage >= pagination.totalPages) return;

    final ctx = ref.read(seasonEventContextProvider);
    if (ctx.seasonId == null) return;
    final generation = _dataGeneration;

    state = AsyncData(
      LeaderboardState(
        result: current.result,
        allEntries: current.allEntries,
        isLoadingMore: true,
      ),
    );

    try {
      final service = ref.read(leaderboardApiServiceProvider);
      final nextPage = _currentPage + 1;

      final result = await service.getLeaderboard(
        seasonId: ctx.seasonId!,
        eventId: ctx.eventId,
        page: nextPage,
        authority: owner.identityLease,
      );

      if (!canPublish(owner) ||
          generation != _dataGeneration ||
          ctx != ref.read(seasonEventContextProvider)) {
        return;
      }
      _currentPage = nextPage;
      state = AsyncData(
        LeaderboardState(
          result: result,
          allEntries: [...current.allEntries, ...result.entries],
        ),
      );
    } catch (e) {
      if (!canPublish(owner) ||
          generation != _dataGeneration ||
          ctx != ref.read(seasonEventContextProvider)) {
        return;
      }
      _log.warn('Failed to load next page: $e');
      state = AsyncData(
        LeaderboardState(
          result: current.result,
          allEntries: current.allEntries,
        ),
      );
    }
  }
}

final leaderboardProvider =
    AsyncNotifierProvider<LeaderboardController, LeaderboardState?>(
  LeaderboardController.new,
);
