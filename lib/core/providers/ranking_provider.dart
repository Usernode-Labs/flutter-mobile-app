import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class RankingController extends LeaderboardNotifier<RankingResult> {
  @override
  bool watchDeps() {
    final pid = ref.watch(participantIdProvider).valueOrNull;
    final sid = ref.watch(
      seasonEventContextProvider.select((ctx) => ctx.seasonId),
    );
    return pid != null && sid != null;
  }

  @override
  Future<RankingResult> fetch() async {
    final participantId = ref.read(participantIdProvider).value!;
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getRanking(
      participantId: participantId,
      seasonId: ctx.seasonId,
    );
  }
}

final rankingProvider =
    AsyncNotifierProvider<RankingController, RankingResult?>(
  RankingController.new,
);
