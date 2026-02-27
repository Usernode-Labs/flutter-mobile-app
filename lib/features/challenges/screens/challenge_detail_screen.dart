import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/utils/challenge_point_tracker.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_detail_page.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_reward_card.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';

/// Feature screen that wires live API data to [ChallengeDetailPage].
///
/// Receives an [EnrichedChallenge] via route extra (identity + optional
/// activity). Watches [breakdownProvider] for [EventBreakdown] metrics and
/// uses [ChallengePointTracker] for 24-hour point diffs.
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challenge});

  final EnrichedChallenge challenge;

  /// SharedPreferences key for this challenge's point snapshots.
  String get _trackerKey => 'challenge_${challenge.dto.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final breakdownAsync = ref.watch(breakdownProvider);
    final breakdown = breakdownAsync.value?.data;
    final eb = breakdown?.eventBreakdown;
    final blocksSummary = ref.watch(producedBlocksSummaryProvider);
    final latestEpoch = blocksSummary.asData?.value.maxEpochWithData;

    // Record point snapshot on each successful data load
    if (challenge.earnedPoints != null) {
      ChallengePointTracker.record(_trackerKey, challenge.earnedPoints!);
    }

    return Theme(
      data: ColorIsExpensiveTheme(textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          ),
      child: Builder(
        builder: (context) => Scaffold(
          body: FutureBuilder<PointDiff?>(
            future: ChallengePointTracker.getDiffBestEffort(_trackerKey),
            builder: (context, diffSnapshot) {
              return _buildPage(context, eb, diffSnapshot.data, latestEpoch);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    EventBreakdown? eb,
    PointDiff? diff,
    int? latestEpoch,
  ) {
    final dto = challenge.dto;
    final category = mapCategory(dto.category);
    final variant = mapEnrichedVariant(challenge);
    final isProduceBlocks = isProduceBlocksChallenge(dto.id);

    // Reward card visibility rules:
    // - Missed: never shown
    // - Completed: always shown (full breakdown for produce-blocks, simple otherwise)
    // - Active: only shown for produce-blocks (full breakdown)
    final bool showRewardCard = switch (variant) {
      ChallengeCardVariant.missed => false,
      ChallengeCardVariant.completed => true,
      ChallengeCardVariant.active ||
      ChallengeCardVariant.ongoing =>
        isProduceBlocks,
    };

    return ChallengeDetailPage(
      title: dto.goal,
      category: category,
      dateRange:
          '${_categoryDisplayName(category)} · ${formatDateRange(dto.scheduleStart, dto.scheduleEnd)}',
      rewardCard: showRewardCard
          ? _buildRewardCard(context, category, eb, diff, latestEpoch)
          : null,
      sections: _buildSections(dto),
      totalRewardHeading: 'Total Reward ${formatRewardText(dto.reward)}',
      totalRewardBody: dto.rewardLogic ?? '',
      onBackTap: () => context.pop(),
    );
  }

  Widget _buildRewardCard(
    BuildContext context,
    ChallengeCategory category,
    EventBreakdown? eb,
    PointDiff? diff,
    int? latestEpoch,
  ) {
    final dto = challenge.dto;
    final isProduceBlocks = isProduceBlocksChallenge(dto.id);

    // Use per-challenge earned points from breakdown activity, not event total.
    final totalEarned = challenge.earnedPoints != null
        ? formatPoints(challenge.earnedPoints!)
        : '--';

    // Epoch section: only for produce-blocks challenges.
    final String? epochEarned;
    final String? epochSectionLabel;
    if (isProduceBlocks) {
      if (diff != null) {
        epochEarned = '+${formatPoints(diff.points)}';
        epochSectionLabel = formatDiffLabel(diff.since);
      } else if (challenge.earnedPoints != null) {
        epochEarned = '+0';
        epochSectionLabel = 'Last 24h';
      } else {
        epochEarned = null;
        epochSectionLabel = null;
      }
    } else {
      epochEarned = null;
      epochSectionLabel = null;
    }

    final ChallengeRewardData data;
    if (isProduceBlocks) {
      final ceiling = parseRewardCeiling(formatRewardText(dto.reward));
      final maxPts = ceiling != null ? ceiling - 1500 : 0;
      final successRate = eb?.successRate ?? 0;

      data = ProduceBlocksRewardData(
        progressFraction: successRate / 100.0,
        successRate: '${successRate.round()}%',
        maxPoints: formatPoints(maxPts),
        totalPoints: formatPoints((successRate * maxPts / 100).round()),
        rankLabel: formatRankOrdinal(eb?.rank),
        rankReward: '+${formatPoints(eb?.top3Points ?? 0)}',
      );
    } else {
      data = const SimpleRewardData();
    }

    return ChallengeRewardCard(
      category: category,
      totalEarned: totalEarned,
      data: data,
      epochSectionLabel: epochSectionLabel,
      epochEarned: epochEarned,
      epochLabel: isProduceBlocks && latestEpoch != null
          ? 'View Epoch $latestEpoch'
          : null,
      onEpochTap: isProduceBlocks && latestEpoch != null
          ? () => context.push(
                AppRoutes.epochPerformance,
                extra: {'initialEpoch': latestEpoch},
              )
          : null,
    );
  }

  List<ChallengeDetailSection> _buildSections(ChallengeDto dto) {
    final sections = <ChallengeDetailSection>[];
    if (dto.description != null && dto.description!.isNotEmpty) {
      sections.add((title: 'The Why', body: dto.description!));
    }
    if (dto.task.isNotEmpty) {
      sections.add((title: 'Task', body: dto.task));
    }
    if (dto.requirements != null && dto.requirements!.isNotEmpty) {
      sections.add((title: 'Requirements', body: dto.requirements!));
    }
    return sections;
  }

  String _categoryDisplayName(ChallengeCategory category) {
    return switch (category) {
      ChallengeCategory.technical => 'Technical',
      ChallengeCategory.community => 'Community',
      ChallengeCategory.flash => 'Flash',
    };
  }
}
