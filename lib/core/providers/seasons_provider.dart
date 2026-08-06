import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class SeasonsController extends LeaderboardNotifier<List<SeasonDto>> {
  // v4's /seasons requires a session token; an unauthenticated call 401s,
  // and the service's 401 handler tears down the whole session (it calls
  // onUnauthorized) — which would kick a restored GUEST back to the auth
  // landing. Same gate every other leaderboard provider already has.
  @override
  bool watchDeps() => ref.watch(isAuthenticatedProvider);

  @override
  Future<List<SeasonDto>> fetch() async {
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getSeasons();
  }
}

final seasonsProvider =
    AsyncNotifierProvider<SeasonsController, List<SeasonDto>?>(
  SeasonsController.new,
);
