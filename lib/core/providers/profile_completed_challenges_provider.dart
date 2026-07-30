import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

class ProfileCompletedChallengeHistory {
  const ProfileCompletedChallengeHistory({
    required this.completed,
    required this.breakdown,
  });

  final List<EnrichedChallenge> completed;
  final BreakdownResult breakdown;
}

/// Completed challenge history for the current profile.
///
/// Profile is participant-centric, but its completed list follows the selected
/// season when one is active. If no season is selected, the provider falls back
/// to the broader participant history exposed by the breakdown contract.
final profileCompletedChallengesProvider =
    FutureProvider<ProfileCompletedChallengeHistory?>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  final ctx = ref.watch(seasonEventContextProvider);

  final service = ref.read(leaderboardApiServiceProvider);
  final seasonId = ctx.seasonId;

  final breakdown = await service.getBreakdown(seasonId: seasonId);
  final challenges = await _fetchProfileChallenges(
    service: service,
    seasonId: seasonId,
    breakdown: breakdown,
  );

  final enriched = enrichChallenges(challenges, extractActivities(breakdown));
  final completed = enriched.where((challenge) {
    final progress = breakdown.progressForChallenge(challenge.dto);
    if (progress == null) return false;
    return progress.state == ChallengeProgressState.earned ||
        progress.earnedPoints > 0;
  }).toList();

  return ProfileCompletedChallengeHistory(
    completed: completed,
    breakdown: breakdown,
  );
});

Future<List<ChallengeDto>> _fetchProfileChallenges({
  required LeaderboardApiService service,
  required int? seasonId,
  required BreakdownResult breakdown,
}) async {
  if (seasonId != null) {
    return service.getChallenges(seasonId: seasonId, activeOnly: false);
  }

  final seasonIds = _seasonIdsWithProfileProgress(breakdown);
  if (seasonIds.isEmpty) {
    return service.getChallenges(activeOnly: false);
  }

  return (await Future.wait([
    for (final seasonId in seasonIds)
      service.getChallenges(seasonId: seasonId, activeOnly: false),
  ]))
      .expand((items) => items)
      .toList(growable: false);
}

Set<int> _seasonIdsWithProfileProgress(BreakdownResult breakdown) {
  if (breakdown.globalSeasons.isNotEmpty) {
    return {
      for (final season in breakdown.globalSeasons) season.seasonId,
    };
  }

  final season = breakdown.seasonBreakdown;
  if (season != null) return {season.seasonId};

  return const {};
}
