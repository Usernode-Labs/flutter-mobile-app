import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class RankingController extends LeaderboardNotifier<RankingResult> {
  @override
  bool watchDeps() {
    final authed = ref.watch(isAuthenticatedProvider);
    final ctx = ref.watch(seasonEventContextProvider);
    return authed && (ctx.eventId != null || ctx.seasonId != null);
  }

  @override
  Future<RankingResult> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getRanking(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
    );
  }
}

final rankingProvider =
    AsyncNotifierProvider<RankingController, RankingResult?>(
  RankingController.new,
);
