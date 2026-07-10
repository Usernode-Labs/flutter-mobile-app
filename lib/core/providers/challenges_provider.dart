import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class ChallengesController extends LeaderboardNotifier<List<ChallengeDto>> {
  @override
  bool watchDeps() {
    ref.watch(seasonEventContextProvider);
    // Refetch once the participant id becomes available so the list comes
    // back with embedded per-challenge activities.
    ref.watch(participantIdProvider.select((p) => p.valueOrNull));
    return true;
  }

  @override
  Future<List<ChallengeDto>> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final participantId = ref.read(participantIdProvider).valueOrNull;
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getChallenges(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
      participantId: participantId,
      activeOnly: true,
    );
  }
}

final challengesProvider =
    AsyncNotifierProvider<ChallengesController, List<ChallengeDto>?>(
  ChallengesController.new,
);
