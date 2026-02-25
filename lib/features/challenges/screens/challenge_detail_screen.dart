import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/breakdown_provider.dart';
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

    // Record point snapshot on each successful data load
    if (eb != null) {
      ChallengePointTracker.record(_trackerKey, eb.totalPoints);
    }

    return Theme(
      data: ColorIsExpensiveTheme(textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          ),
      child: Builder(
        builder: (context) => Scaffold(
          body: FutureBuilder<int?>(
            future: ChallengePointTracker.getDiff24h(_trackerKey),
            builder: (context, diffSnapshot) {
              return _buildPage(context, eb, diffSnapshot.data);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, EventBreakdown? eb, int? diff24h) {
    final dto = challenge.dto;
    final category = mapCategory(dto.category);

    return ChallengeDetailPage(
      title: dto.goal,
      category: category,
      dateRange:
          '${_categoryDisplayName(category)} · ${formatDateRange(dto.scheduleStart, dto.scheduleEnd)}',
      rewardCard: _buildRewardCard(category, eb, diff24h),
      sections: _buildSections(dto),
      totalRewardHeading: 'Total Reward ${formatRewardText(dto.reward)}',
      totalRewardBody: dto.rewardLogic ?? '',
      onBackTap: () => context.pop(),
      titleHeroTag: 'challenge_title_${dto.id}',
      entranceAnimation: ModalRoute.of(context)?.animation,
    );
  }

  Widget _buildRewardCard(
    ChallengeCategory category,
    EventBreakdown? eb,
    int? diff24h,
  ) {
    final dto = challenge.dto;
    final maxPtsRaw = int.tryParse(dto.reward);

    final totalEarned = eb != null ? formatPoints(eb.totalPoints) : '--';
    final successRate = eb?.successRate ?? 0;
    final progressFraction = successRate / 100.0;
    final successRateLabel = '${successRate.round()}%';
    final maxPointsLabel =
        maxPtsRaw != null ? formatPoints(maxPtsRaw) : dto.reward;
    final totalPointsLabel = maxPtsRaw != null
        ? formatPoints((successRate * maxPtsRaw / 100).round())
        : '--';
    final rankReward = '+${formatPoints(eb?.top3Points ?? 0)}';

    final epochEarned = diff24h != null ? '+${formatPoints(diff24h)}' : null;

    return ChallengeRewardCard(
      category: category,
      totalEarned: totalEarned,
      progressFraction: progressFraction,
      successRate: successRateLabel,
      maxPoints: maxPointsLabel,
      totalPoints: totalPointsLabel,
      rankReward: rankReward,
      epochSectionLabel: 'Last 24h',
      epochEarned: epochEarned,
      epochLabel: eb != null ? 'View Epoch ${eb.eventName}' : null,
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
