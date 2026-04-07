import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/syncing_text_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/utils/challenge_point_tracker.dart';
import 'package:crypto_mobile_app/design_system/src/block_production_status_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_detail_page.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_reward_card.dart';
import 'package:crypto_mobile_app/design_system/src/status_badge.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
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
    final breakdown = ref.watch(breakdownProvider).valueOrNull;
    // Season-scoped breakdown: find the EventBreakdown matching this
    // challenge's event for bonus fields (top3, firstBlock, success50%).
    final eb = breakdown?.eventBreakdown ??
        breakdown?.seasonBreakdown?.events
            .firstWhereOrNull((e) => e.eventId == challenge.dto.eventId);
    final blocksSummary = ref.watch(producedBlocksSummaryProvider);
    final nodeStatus = ref.watch(nodeStatusProvider).asData?.value;
    final latestEpoch = nodeStatus?.currentEpoch;
    // Record point snapshot on each successful data load (skip 0 — aggregator
    // may not have tallied yet, recording 0 would skew the 24-hour diff).
    if (challenge.earnedPoints != null && challenge.earnedPoints! > 0) {
      ChallengePointTracker.record(_trackerKey, challenge.earnedPoints!);
    }

    return Scaffold(
      body: FutureBuilder<PointDiff?>(
        future: ChallengePointTracker.getDiffBestEffort(_trackerKey),
        builder: (context, diffSnapshot) {
          return _buildPage(
            context,
            ref,
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
    WidgetRef ref,
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
          ? _buildRewardCard(context, ref, category, eb, diff, latestEpoch)
          : null,
      statusSection: isProduceBlocks
          ? _buildStatusSection(
              context,
              ref,
              nodeStatus,
              blocksSummaryData,
              latestEpoch,
            )
          : null,
      sections: _buildSections(context, dto),
      totalRewardHeading: showRewardCard
          ? null
          : AppLocalizations.of(
              context,
            ).challengeTotalReward(formatRewardText(dto.reward)),
      totalRewardBody: showRewardCard ? null : (dto.rewardLogic ?? ''),
      onBackTap: () => context.pop(),
    );
  }

  Widget _buildRewardCard(
    BuildContext context,
    WidgetRef ref,
    ChallengeCategory category,
    EventBreakdown? eb,
    PointDiff? diff,
    int? latestEpoch,
  ) {
    final dto = challenge.dto;
    final isProduceBlocks = isProduceBlocksChallenge(dto);
    final successRate = eb?.successRate ?? 0;

    // Max success-rate points for the progress breakdown display.
    final ceiling = isProduceBlocks
        ? parseRewardCeiling(formatRewardText(dto.reward))
        : null;
    final maxPts = ceiling != null ? ceiling - kTop3RankBonusPoints : 0;

    // earnedPoints includes extra points; base is the success-rate calculation only.
    final earnedPoints = challenge.earnedPoints;
    final basePoints = challenge.activity?.points;
    final extraPointsTotal = challenge.extraPoints;
    final isSyncing = isProduceBlocksSyncing(
      isProduceBlocks: isProduceBlocks,
      earnedPoints: basePoints,
      successRate: successRate,
    );
    final syncingText = isSyncing
        ? ref.watch(syncingTextProvider).valueOrNull ?? kSyncingTextFallback
        : null;
    // Calculation row shows base points (success rate × max pts).
    final displayBasePoints =
        syncingText ?? (basePoints != null ? formatPoints(basePoints) : '--');
    // Total earned includes base + extra + all bonuses.
    final totalWithBonuses = (earnedPoints ?? 0) + (eb?.totalBonusPoints ?? 0);
    final displayTotalEarned = syncingText ??
        (earnedPoints != null ? formatPoints(totalWithBonuses) : '--');

    // Epoch section: only for produce-blocks challenges.
    final String? epochEarned;
    final String? epochSectionLabel;
    if (isProduceBlocks) {
      if (diff != null) {
        epochEarned = '+${formatPoints(diff.points)}';
        epochSectionLabel = formatDiffLabel(diff.since);
      } else if (earnedPoints != null || successRate > 0) {
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
        totalPoints: displayBasePoints,
        rankLabel: formatRankOrdinal(eb?.rank),
        rankReward: '+${formatPoints(eb?.top3Points ?? 0)}',
        rateLabel: dto.completed ? 'SUCCESS RATE' : 'BLOCK RATE',
        extraPoints:
            extraPointsTotal > 0 ? '+${formatPoints(extraPointsTotal)}' : null,
        firstBlockReward: (eb?.firstBlockPoints ?? 0) > 0
            ? '+${formatPoints(eb!.firstBlockPoints!)}'
            : null,
        successReward: (eb?.success50PercentPoints ?? 0) > 0
            ? '+${formatPoints(eb!.success50PercentPoints!)}'
            : null,
      );
    } else {
      data = const SimpleRewardData();
    }

    return ChallengeRewardCard(
      category: category,
      totalEarned: isProduceBlocks ? displayTotalEarned : displayBasePoints,
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
    BuildContext context,
    ChallengeDto dto,
  ) {
    final l10n = AppLocalizations.of(context);
    final sections = <ChallengeDetailSection>[];
    if (dto.description != null && dto.description!.isNotEmpty) {
      sections.add((
        title: l10n.challengeSectionTheWhy,
        body: dto.description!,
      ));
    }
    if (dto.task.isNotEmpty) {
      sections.add((title: l10n.challengeSectionTask, body: dto.task));
    }
    if (dto.requirements != null && dto.requirements!.isNotEmpty) {
      sections.add((
        title: l10n.challengeSectionRequirements,
        body: dto.requirements!,
      ));
    }
    return sections;
  }

  Widget _buildStatusSection(
    BuildContext context,
    WidgetRef ref,
    NodeStatusState? nodeStatus,
    ProducedBlocksSummary? summary,
    int? currentEpoch,
  ) {
    // Network step — always tappable, navigates to Node Status tab
    void networkOnTap() {
      ref.read(currentHomeTabProvider.notifier).state = HomeTab.nodeStatus;
      context.go(AppRoutes.home);
    }

    final PipelineStepStatus networkStep;
    if (nodeStatus == null) {
      networkStep = PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: const StepTrailingBadge(
          label: 'Loading',
          variant: StatusBadgeVariant.neutral,
        ),
        onTap: networkOnTap,
      );
    } else if (nodeStatus.connectedPeers > 0) {
      networkStep = PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: const StepTrailingBadge(
          label: 'Connected',
          variant: StatusBadgeVariant.success,
        ),
        onTap: networkOnTap,
      );
    } else {
      networkStep = PipelineStepStatus(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        trailing: const StepTrailingBadge(
          label: 'Disconnected',
          variant: StatusBadgeVariant.error,
        ),
        onTap: networkOnTap,
      );
    }

    // VRF step — tappable when currentEpoch is known
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
      onTap: currentEpoch != null && summary != null
          ? () => _navigateToSlots(context, summary, currentEpoch, ['all'])
          : null,
    );

    // Next Block step — find first scheduled slot with future time
    final PipelineStepStatus nextBlockStep;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    String? nextBlockText;

    if (summary != null) {
      // Forward iteration: past epochs have no scheduled slots (converted to missed),
      // so this naturally finds the nearest upcoming slot in the current epoch first.
      for (final epochScore in summary.epochScores) {
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

    // Next Block — tappable when there are upcoming slots
    final hasUpcoming = nextBlockText != null;
    if (hasUpcoming) {
      nextBlockStep = PipelineStepStatus(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        trailing: StepTrailingText(text: nextBlockText),
        onTap: summary != null
            ? () =>
                _navigateToSlots(context, summary, currentEpoch, ['upcoming'])
            : null,
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

    // Last Produced — tappable when there are produced blocks
    final hasProduced = lastProducedTimeMs != null;
    if (hasProduced) {
      final agoMs = nowMs - lastProducedTimeMs.toInt();
      lastProducedStep = PipelineStepStatus(
        label: 'Last Produced',
        icon: Symbols.check_circle_sharp,
        trailing: StepTrailingText(text: _formatTimeAgo(agoMs)),
        onTap: summary != null
            ? () =>
                _navigateToSlots(context, summary, currentEpoch, ['produced'])
            : null,
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

    // Missed Blocks step — count from current epoch
    final PipelineStepStatus? missedBlocksStep;
    if (summary != null && currentEpoch != null) {
      final currentScore =
          (currentEpoch >= 0 && currentEpoch < summary.epochScores.length)
              ? summary.epochScores[currentEpoch]
              : null;
      final missed = currentScore?.missed ?? 0;
      missedBlocksStep = PipelineStepStatus(
        label: 'Missed Blocks',
        icon: Symbols.disabled_by_default_sharp,
        trailing: missed > 0
            ? StepTrailingText(
                text: '$missed ${missed == 1 ? 'block' : 'blocks'}',
              )
            : const StepTrailingBadge(
                label: 'None',
                variant: StatusBadgeVariant.success,
              ),
        onTap: missed > 0
            ? () => _navigateToSlots(context, summary, currentEpoch, ['missed'])
            : null,
      );
    } else {
      missedBlocksStep = null;
    }

    return BlockProductionStatusCard(
      data: BlockProductionStatusData(
        network: networkStep,
        vrf: vrfStep,
        nextBlock: nextBlockStep,
        lastProduced: lastProducedStep,
        missedBlocks: missedBlocksStep,
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

  /// Navigate to slot assignments with extracted slot data.
  static void _navigateToSlots(
    BuildContext context,
    ProducedBlocksSummary data,
    int? currentEpoch,
    List<String> filters,
  ) {
    if (currentEpoch == null) return;
    final score = (currentEpoch >= 0 && currentEpoch < data.epochScores.length)
        ? data.epochScores[currentEpoch]
        : null;
    final epochData = score?.epochData.slotData;
    final results = epochData == null
        ? <int>[]
        : epochData.map((s) => s.result.index).toList();
    final slotTimesMs = epochData == null
        ? <int?>[]
        : epochData.map((s) => s.slotTimeMs?.toInt()).toList();
    final producedMeta = epochData == null
        ? const <Map<String, dynamic>?>[]
        : epochData
            .map(
              (s) => s.producedBlockMetadata == null
                  ? null
                  : <String, dynamic>{
                      'blockHash':
                          s.producedBlockMetadata!.blockHash.toString(),
                      'canonical': s.producedBlockMetadata!.canonical,
                      'timestampMs':
                          s.producedBlockMetadata!.timestampMs.toString(),
                      'tokensWon':
                          s.producedBlockMetadata!.tokensWon.toString(),
                    },
            )
            .toList();

    context.push(
      AppRoutes.slotAssignments,
      extra: {
        'epoch': currentEpoch,
        'slotsInEpoch': data.slotsInEpoch,
        'results': results,
        'slotTimesMs': slotTimesMs,
        'producedMeta': producedMeta,
        'filters': filters,
      },
    );
  }

  String _categoryDisplayName(ChallengeCategory category) {
    return switch (category) {
      ChallengeCategory.technical => 'Technical',
      ChallengeCategory.community => 'Community',
      ChallengeCategory.flash => 'Flash',
    };
  }
}
