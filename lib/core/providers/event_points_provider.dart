import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class EventPointsController extends LeaderboardNotifier<EventPointsResult> {
  @override
  bool watchDeps() {
    final ctx = ref.watch(seasonEventContextProvider);
    return ctx.seasonId != null && ctx.eventId != null;
  }

  @override
  Future<EventPointsResult> fetch(AuthenticatedUserLease owner) async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getEventPoints(
      eventId: ctx.eventId!,
      authority: owner,
    );
  }
}

final eventPointsProvider =
    AsyncNotifierProvider<EventPointsController, EventPointsResult?>(
  EventPointsController.new,
);
