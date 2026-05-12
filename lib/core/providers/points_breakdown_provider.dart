import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class BreakdownController extends LeaderboardNotifier<BreakdownResult> {
  @override
  bool watchDeps() {
    final pid = ref.watch(participantIdProvider).valueOrNull;
    final sid = ref.watch(
      seasonEventContextProvider.select((ctx) => ctx.seasonId),
    );
    return pid != null && sid != null;
  }

  @override
  bool canRefresh() {
    final pid = ref.read(participantIdProvider).valueOrNull;
    final sid = ref.read(seasonEventContextProvider).seasonId;
    return pid != null && sid != null;
  }

  @override
  Future<BreakdownResult> fetch() async {
    final participantId = ref.read(participantIdProvider).value!;
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    final result = await service.getBreakdown(
      participantId: participantId,
      seasonId: ctx.seasonId,
    );
    // Update participant event IDs for the event picker filter.
    if (result.seasonBreakdown != null) {
      final ids = result.seasonBreakdown!.events.map((e) => e.eventId).toSet();
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
