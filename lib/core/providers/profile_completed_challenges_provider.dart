import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
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
/// Profile is participant-centric, so it intentionally fetches global
/// challenge progress instead of inheriting the Challenges page's selected
/// season/event scope.
final profileCompletedChallengesProvider =
    FutureProvider<ProfileCompletedChallengeHistory?>((ref) async {
  final participantId = await ref.watch(participantIdProvider.future);
  if (participantId == null) return null;

  final service = ref.read(leaderboardApiServiceProvider);
  final challengesFuture = service.getChallenges(
    participantId: participantId,
    activeOnly: false,
  );
  final breakdownFuture = service.getBreakdown(participantId: participantId);

  final challenges = await challengesFuture;
  final breakdown = await breakdownFuture;
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
