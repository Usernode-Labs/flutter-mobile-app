import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/providers/challenges_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

/// Bands to render plus an id → [EnrichedChallenge] lookup so card taps can
/// route to the detail screen with the full challenge.
typedef ChallengeBandsResult = ({
  List<ChallengeBand> bands,
  Map<int, EnrichedChallenge> byId,
});

/// Derived provider that turns the raw challenges + breakdown into the
/// perceived-time bands (Featured / Today / This week / Season) of atomic cards
/// rendered by the new Challenges surface.
///
/// Recomputes only when [challengesProvider] or [breakdownProvider] emit. When
/// the breakdown carries explicit `challenge_progress[]` (mock / future API) it
/// drives the card phase/fill precisely; otherwise the mapper derives a generic
/// status from schedule + activities.
final challengeBandsProvider = Provider<ChallengeBandsResult?>((ref) {
  final challenges = ref.watch(challengesProvider.select((s) => s.valueOrNull));
  if (challenges == null) return null;

  final breakdown = ref.watch(breakdownProvider.select((s) => s.valueOrNull));
  final activities = extractActivities(breakdown);
  final enriched = enrichChallenges(challenges, activities);

  final progress = breakdown?.challengeProgress;
  final progressById = (progress == null || progress.isEmpty)
      ? null
      : {for (final p in progress) p.challengeId: p};

  return (
    bands: buildChallengeBands(enriched, progressById: progressById),
    byId: {for (final c in enriched) c.dto.id: c},
  );
});
