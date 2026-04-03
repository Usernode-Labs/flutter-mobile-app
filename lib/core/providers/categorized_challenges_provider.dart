import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

/// Memoized derived provider that enriches and categorizes challenges.
///
/// Recomputes only when [challengesProvider] or [breakdownProvider] emit
/// new values — not on every build frame.
final categorizedChallengesProvider = Provider<CategorizedEnrichedChallenges?>((
  ref,
) {
  final challenges = ref.watch(challengesProvider.select((s) => s.valueOrNull));
  if (challenges == null) return null;
  final breakdown = ref.watch(breakdownProvider.select((s) => s.valueOrNull));
  final activities = extractActivities(breakdown);
  final enriched = enrichChallenges(challenges, activities);
  return categorizeEnrichedChallenges(enriched);
});
