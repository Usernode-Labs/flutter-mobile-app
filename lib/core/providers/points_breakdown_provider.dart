import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class BreakdownController extends LeaderboardNotifier<BreakdownResult> {
  @override
  bool watchDeps() {
    final pid = ref.watch(participantIdProvider).valueOrNull;
    final ctx = ref.watch(seasonEventContextProvider);
    return pid != null && ctx.seasonId != null;
  }

  @override
  Future<BreakdownResult> fetch() async {
    final participantId = ref.read(participantIdProvider).value!;
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getBreakdown(
      participantId: participantId,
      seasonId: ctx.seasonId,
      eventId: ctx.eventId,
    );
  }
}

final breakdownProvider =
    AsyncNotifierProvider<BreakdownController, BreakdownResult?>(
      BreakdownController.new,
    );
