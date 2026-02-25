import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

/// Memoized derived provider that enriches and categorizes challenges.
///
/// Recomputes only when [challengesProvider] or [breakdownProvider] emit
/// new values — not on every build frame.
final categorizedChallengesProvider =
    Provider<CategorizedEnrichedChallenges?>((ref) {
  final challenges = ref.watch(challengesProvider).value?.data;
  if (challenges == null) return null;
  final breakdown = ref.watch(breakdownProvider).value?.data;
  final activities = extractActivities(breakdown);
  final enriched = enrichChallenges(challenges, activities);
  return categorizeEnrichedChallenges(enriched);
});
