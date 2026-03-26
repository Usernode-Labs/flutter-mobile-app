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
  final challenges = ref.watch(challengesProvider.select((s) => s.value));
  if (challenges == null) return null;
  final enabled = challenges.where((c) => c.enabled).toList();
  final breakdown = ref.watch(breakdownProvider.select((s) => s.value));
  final activities = extractActivities(breakdown);
  final enriched = enrichChallenges(enabled, activities);
  return categorizeEnrichedChallenges(enriched);
});
