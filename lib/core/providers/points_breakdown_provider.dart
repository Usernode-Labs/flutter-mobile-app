import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class BreakdownController extends LeaderboardNotifier<BreakdownResult> {
  @override
  bool watchDeps() {
    final authed = ref.watch(isAuthenticatedProvider);
    final ctx = ref.watch(seasonEventContextProvider);
    return authed && (ctx.eventId != null || ctx.seasonId != null);
  }

  @override
  Future<BreakdownResult> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    final result = await service.getBreakdown(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
    );
    // Update participant event IDs for the event picker filter.
    if (result.seasonBreakdown != null) {
      final ids = result.seasonBreakdown!.events.map((e) => e.eventId).toSet();
      final prev = ref.read(participantEventIdsProvider);
      if (ids.length != prev.length || !ids.containsAll(prev)) {
        ref.read(participantEventIdsProvider.notifier).state = ids;
      }
    } else if (result.globalSeasons.isNotEmpty) {
      final ids = result.globalSeasons
          .expand((season) => season.events)
          .map((event) => event.eventId)
          .toSet();
      final prev = ref.read(participantEventIdsProvider);
      if (ids.length != prev.length || !ids.containsAll(prev)) {
        ref.read(participantEventIdsProvider.notifier).state = ids;
      }
    }
    return result;
  }
}

final breakdownProvider =
    AsyncNotifierProvider<BreakdownController, BreakdownResult?>(
  BreakdownController.new,
);
