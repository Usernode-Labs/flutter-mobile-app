import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class ChallengesController extends LeaderboardNotifier<List<ChallengeDto>> {
  @override
  bool watchDeps() {
    ref.watch(seasonEventContextProvider);
    // Gate on a session: the server embeds the authed participant's per-challenge
    // activities, resolved from the token.
    return ref.watch(isAuthenticatedProvider);
  }

  @override
  Future<List<ChallengeDto>> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getChallenges(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
      activeOnly: true,
    );
  }
}

final challengesProvider =
    AsyncNotifierProvider<ChallengesController, List<ChallengeDto>?>(
  ChallengesController.new,
);
