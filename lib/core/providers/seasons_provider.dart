import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_notifier.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';

class SeasonsController extends LeaderboardNotifier<List<SeasonDto>> {
  @override
  Future<List<SeasonDto>> fetch(AuthenticatedUserLease owner) async {
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getSeasons(authority: owner.identityLease);
  }
}

final seasonsProvider =
    AsyncNotifierProvider<SeasonsController, List<SeasonDto>?>(
  SeasonsController.new,
);
