import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/models/zk_identity_models.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';

/// Memoized derived provider that enriches and categorizes challenges.
///
/// Recomputes only when [challengesProvider] or [breakdownProvider] emit
/// new values — not on every build frame.
final categorizedChallengesProvider =
    Provider<CategorizedEnrichedChallenges?>((ref) {
  final challenges = ref.watch(challengesProvider.select((s) => s.value?.data));
  if (challenges == null) return null;
  final breakdown = ref.watch(breakdownProvider.select((s) => s.value?.data));
  final activities = extractActivities(breakdown);
  final enriched = enrichChallenges(challenges, activities);
  final categorized = categorizeEnrichedChallenges(enriched);

  // Inject synthetic ZK Identity challenge
  final isComplete = ref.watch(
    zkIdentityIsCompleteProvider.select(
      (v) => v.maybeWhen(data: (d) => d, orElse: () => false),
    ),
  );
  const config = ZkIdentityChallengeConfig.instance;
  final zkDto = ChallengeDto(
    id: ZkIdentityChallengeConfig.syntheticId,
    category: config.category,
    goal: config.goal,
    task: config.task,
    reward: config.reward,
    enabled: true,
    completed: isComplete,
    subCategory: config.subCategory,
  );
  final zkEnriched = EnrichedChallenge(dto: zkDto);

  if (isComplete) {
    return CategorizedEnrichedChallenges(
      active: categorized.active,
      completed: [zkEnriched, ...categorized.completed],
      missed: categorized.missed,
    );
  }
  return CategorizedEnrichedChallenges(
    active: [zkEnriched, ...categorized.active],
    completed: categorized.completed,
    missed: categorized.missed,
  );
});
