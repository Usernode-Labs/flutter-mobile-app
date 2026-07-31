import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class BreakdownController extends LeaderboardNotifier<BreakdownResult> {
  @override
  bool watchDeps() {
    final ctx = ref.watch(seasonEventContextProvider);
    return ctx.eventId != null || ctx.seasonId != null;
  }

  @override
  Future<BreakdownResult> fetch(AuthenticatedUserLease owner) async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    final result = await service.getBreakdown(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
      authority: owner.identityLease,
    );
    // The request can finish after this notifier has been invalidated for a
    // replacement identity. Never let that old result mutate the new owner's
    // event picker state.
    if (!canPublish(owner)) return result;

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
