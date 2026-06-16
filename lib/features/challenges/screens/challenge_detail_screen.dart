import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/utils/challenge_cta_dispatcher.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';

/// Feature screen that wires a challenge to the simplified
/// [AtomicChallengeDetailPage].
///
/// Receives an [EnrichedChallenge] via route extra and resolves the matching
/// per-challenge [ChallengeProgress] from [breakdownProvider] (when the backend
/// supplies it) so the detail rail mirrors the card exactly. The CTA routes
/// through the shared [handleChallengeCta] dispatcher (url → browser, app →
/// in-app GoRouter path).
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challenge});

  final EnrichedChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dto = challenge.dto;

    final progress = ref.watch(
      breakdownProvider.select(
        (s) => s.valueOrNull?.challengeProgress
            ?.firstWhereOrNull((p) => p.challengeId == dto.id),
      ),
    );

    final card = mapToAtomicCard(challenge, progress: progress);
    final dateText = formatDateRange(dto.scheduleStart, dto.scheduleEnd);

    return AtomicChallengeDetailPage(
      title: dto.goal,
      description:
          (dto.description?.isNotEmpty ?? false) ? dto.description! : dto.task,
      leftText: card.leftText,
      rightText: card.rightText,
      phase: card.phase,
      fill: card.fill,
      railTreatment: card.railTreatment,
      dateText: dateText.isNotEmpty ? dateText : 'Available now',
      pointsLogic: (dto.rewardLogic?.isNotEmpty ?? false)
          ? dto.rewardLogic!
          : 'Points are awarded once this challenge is completed and verified.',
      ctaLabel: (dto.ctaLabel?.isNotEmpty ?? false)
          ? dto.ctaLabel!
          : 'Join the challenge',
      rules: dto.requirements,
      onBackTap: () {
        if (context.canPop()) context.pop();
      },
      onCtaTap: () => handleChallengeCta(context, dto),
    );
  }
}
