import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/utils/challenge_point_tracker.dart';
import 'package:crypto_mobile_app/design_system/src/block_production_status_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_detail_page.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_reward_card.dart';
import 'package:crypto_mobile_app/design_system/src/status_badge.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

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
    final breakdownAsync = ref.watch(breakdownProvider);
    final breakdown = breakdownAsync.value?.data;
    final eb = breakdown?.eventBreakdown;
    final blocksSummary = ref.watch(producedBlocksSummaryProvider);
    final nodeStatus = ref.watch(nodeStatusProvider).asData?.value;
    final latestEpoch = nodeStatus?.currentEpoch;

    // Record point snapshot on each successful data load
    if (challenge.earnedPoints != null) {
      ChallengePointTracker.record(_trackerKey, challenge.earnedPoints!);
    }

    return Scaffold(
      body: FutureBuilder<PointDiff?>(
        future: ChallengePointTracker.getDiffBestEffort(_trackerKey),
        builder: (context, diffSnapshot) {
          return _buildPage(
            context,
            eb,
            diffSnapshot.data,
            latestEpoch,
            nodeStatus,
            blocksSummary.asData?.value,
          );
        },
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    EventBreakdown? eb,
    PointDiff? diff,
    int? latestEpoch,
    NodeStatusState? nodeStatus,
    ProducedBlocksSummary? blocksSummaryData,
  ) {
    final dto = challenge.dto;
    final category = mapCategory(dto.category);
    final variant = mapEnrichedVariant(
      challenge,
      eventSuccessRate: eb?.successRate,
    );
    final isProduceBlocks = isProduceBlocksChallenge(dto);

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
      statusSection: isProduceBlocks
          ? _buildStatusSection(nodeStatus, blocksSummaryData)
          : null,
      sections: _buildSections(context, dto),
      totalRewardHeading: showRewardCard
          ? null
          : AppLocalizations.of(context)
              .challengeTotalReward(formatRewardText(dto.reward)),
      totalRewardBody: showRewardCard ? null : (dto.rewardLogic ?? ''),
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
    final isProduceBlocks = isProduceBlocksChallenge(dto);

    // Compute maxPts early so it's available for the reward card breakdown.
    final ceiling = isProduceBlocks
        ? parseRewardCeiling(formatRewardText(dto.reward))
        : null;
    // TODO(challenges): The API should return maxSuccessRatePoints and
    // top3Bonus separately so the client doesn't embed reward-formula
    // constants. See kTop3RankBonusPoints.
    final maxPts = ceiling != null ? ceiling - kTop3RankBonusPoints : 0;
    final successRate = eb?.successRate ?? 0;

    // Use per-challenge earned points from breakdown activity, not event total.
    // For produce-blocks, fall back to event-level successRate × maxPts when
    // no per-challenge activity match exists.
    final effectiveEarned = isProduceBlocks
        ? computeEffectiveEarnedPoints(
            earnedPoints: challenge.earnedPoints,
            successRate: successRate,
            rewardText: dto.reward,
          )
        : challenge.earnedPoints;
    final totalEarned =
        effectiveEarned != null ? formatPoints(effectiveEarned) : '--';

    // Epoch section: only for produce-blocks challenges.
    final String? epochEarned;
    final String? epochSectionLabel;
    if (isProduceBlocks) {
      if (diff != null) {
        epochEarned = '+${formatPoints(diff.points)}';
        epochSectionLabel = formatDiffLabel(diff.since);
      } else if (challenge.earnedPoints != null || successRate > 0) {
        epochEarned = AppLocalizations.of(context).challengeEpochNoChange;
        epochSectionLabel = AppLocalizations.of(context).challengeEpochLast24h;
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
      data = ProduceBlocksRewardData(
        progressFraction: successRate / 100.0,
        successRate: '${successRate.round()}%',
        maxPoints: formatPoints(maxPts),
        // TODO(challenges): The server should return pre-computed
        // successRatePoints so the client doesn't duplicate business logic.
        totalPoints: formatPoints((successRate * maxPts / 100).round()),
        rankLabel: formatRankOrdinal(eb?.rank),
        rankReward: '+${formatPoints(eb?.top3Points ?? 0)}',
        rateLabel: dto.completed ? 'SUCCESS RATE' : 'BLOCK RATE',
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
          ? AppLocalizations.of(context).challengeViewEpochDetails
          : null,
      onEpochTap: isProduceBlocks && latestEpoch != null
          ? () => context.push(
                AppRoutes.epochPerformance,
                extra: {'initialEpoch': latestEpoch},
              )
          : null,
    );
  }

  List<ChallengeDetailSection> _buildSections(
      BuildContext context, ChallengeDto dto) {
    final l10n = AppLocalizations.of(context);
    final sections = <ChallengeDetailSection>[];
    if (dto.description != null && dto.description!.isNotEmpty) {
      sections
          .add((title: l10n.challengeSectionTheWhy, body: dto.description!));
    }
    if (dto.task.isNotEmpty) {
      sections.add((title: l10n.challengeSectionTask, body: dto.task));
    }
    if (dto.requirements != null && dto.requirements!.isNotEmpty) {
      sections.add(
          (title: l10n.challengeSectionRequirements, body: dto.requirements!));
    }
    return sections;
  }

  Widget _buildStatusSection(
    NodeStatusState? nodeStatus,
    ProducedBlocksSummary? summary,
  ) {
    // Network step
    final PipelineStepStatus networkStep;
    if (nodeStatus == null) {
      networkStep = const PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: StepTrailingBadge(
          label: 'Loading',
          variant: StatusBadgeVariant.neutral,
        ),
      );
    } else if (nodeStatus.connectedPeers > 0) {
      networkStep = const PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: StepTrailingBadge(
          label: 'Connected',
          variant: StatusBadgeVariant.success,
        ),
      );
    } else {
      networkStep = const PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: StepTrailingBadge(
          label: 'Disconnected',
          variant: StatusBadgeVariant.error,
        ),
      );
    }

    // VRF step
    final PipelineStepStatus vrfStep;
    final vrfStatus = nodeStatus?.vrfEvaluator?.currentEpochVrfEvaluationStatus;
    vrfStep = PipelineStepStatus(
      label: 'VRF Calculation',
      icon: Symbols.casino_sharp,
      trailing: switch (vrfStatus) {
        RpcStatusVrfEvaluationStatus.completed => const StepTrailingBadge(
            label: 'Complete',
            variant: StatusBadgeVariant.success,
          ),
        RpcStatusVrfEvaluationStatus.evaluating => const StepTrailingBadge(
            label: 'Evaluating',
            variant: StatusBadgeVariant.info,
          ),
        RpcStatusVrfEvaluationStatus.pending => const StepTrailingBadge(
            label: 'Pending',
            variant: StatusBadgeVariant.neutral,
          ),
        null => const StepTrailingBadge(
            label: 'Unknown',
            variant: StatusBadgeVariant.neutral,
          ),
      },
    );

    // Next Block step — find first scheduled slot with future time
    final PipelineStepStatus nextBlockStep;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    String? nextBlockText;

    if (summary != null) {
      // Search current epoch first, then look ahead
      for (final epochScore in summary.epochScores.reversed) {
        final slots = epochScore.epochData.slotData;
        if (slots == null) continue;
        for (final slot in slots) {
          if (slot.result == RpcSlotResult.scheduled &&
              slot.slotTimeMs != null &&
              slot.slotTimeMs!.toInt() > nowMs) {
            final diffMs = slot.slotTimeMs!.toInt() - nowMs;
            nextBlockText = _formatRelativeTime(diffMs);
            break;
          }
        }
        if (nextBlockText != null) break;
      }
    }

    if (nextBlockText != null) {
      nextBlockStep = PipelineStepStatus(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        trailing: StepTrailingText(text: nextBlockText),
      );
    } else if (vrfStatus == RpcStatusVrfEvaluationStatus.completed) {
      nextBlockStep = const PipelineStepStatus(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        trailing: StepTrailingBadge(
          label: 'None this epoch',
          variant: StatusBadgeVariant.neutral,
        ),
      );
    } else {
      nextBlockStep = const PipelineStepStatus(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        trailing: StepTrailingBadge(
          label: 'Waiting for VRF',
          variant: StatusBadgeVariant.neutral,
        ),
      );
    }

    // Last Produced step — find most recent produced slot across all epochs
    final PipelineStepStatus lastProducedStep;
    BigInt? lastProducedTimeMs;

    if (summary != null) {
      for (final epochScore in summary.epochScores.reversed) {
        final slots = epochScore.epochData.slotData;
        if (slots == null) continue;
        for (final slot in slots.reversed) {
          if (slot.result == RpcSlotResult.produced &&
              slot.slotTimeMs != null) {
            if (lastProducedTimeMs == null ||
                slot.slotTimeMs! > lastProducedTimeMs) {
              lastProducedTimeMs = slot.slotTimeMs;
            }
            break; // Found latest in this epoch, check earlier epochs
          }
        }
        if (lastProducedTimeMs != null) break;
      }
    }

    if (lastProducedTimeMs != null) {
      final agoMs = nowMs - lastProducedTimeMs.toInt();
      lastProducedStep = PipelineStepStatus(
        label: 'Last Produced',
        icon: Symbols.check_circle_sharp,
        trailing: StepTrailingText(text: _formatTimeAgo(agoMs)),
      );
    } else {
      lastProducedStep = const PipelineStepStatus(
        label: 'Last Produced',
        icon: Symbols.check_circle_sharp,
        trailing: StepTrailingBadge(
          label: 'None yet',
          variant: StatusBadgeVariant.neutral,
        ),
      );
    }

    return BlockProductionStatusCard(
      data: BlockProductionStatusData(
        network: networkStep,
        vrf: vrfStep,
        nextBlock: nextBlockStep,
        lastProduced: lastProducedStep,
      ),
    );
  }

  /// Formats a future time difference as "in ~X min" or "in ~X h".
  static String _formatRelativeTime(int diffMs) {
    final minutes = diffMs ~/ 60000;
    if (minutes < 1) return 'in < 1 min';
    if (minutes < 60) return 'in ~$minutes min';
    final hours = minutes ~/ 60;
    final remainingMin = minutes % 60;
    if (remainingMin == 0) return 'in ~$hours h';
    return 'in ~$hours h $remainingMin min';
  }

  /// Formats a past time difference as "X min ago", "X h ago", etc.
  static String _formatTimeAgo(int agoMs) {
    final minutes = agoMs ~/ 60000;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '$minutes min ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '$hours h ago';
    final days = hours ~/ 24;
    return '$days d ago';
  }

  String _categoryDisplayName(ChallengeCategory category) {
    return switch (category) {
      ChallengeCategory.technical => 'Technical',
      ChallengeCategory.community => 'Community',
      ChallengeCategory.flash => 'Flash',
    };
  }
}
