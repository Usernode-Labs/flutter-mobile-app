import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/points_breakdown_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/providers/syncing_text_provider.dart';
import 'package:crypto_mobile_app/core/utils/challenge_point_tracker.dart';
import 'package:crypto_mobile_app/core/utils/challenge_cta_dispatcher.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_presentation_l10n.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

/// Feature screen that wires live challenge data to a detail page.
///
/// Receives an [EnrichedChallenge] via route extra and resolves the matching
/// per-challenge [ChallengeProgress] from [breakdownProvider]. All challenges
/// render through [AtomicChallengeDetailPage]; produce-blocks enriches its hero
/// with live reward/status/epoch affordances.
class ChallengeDetailScreen extends ConsumerWidget {
  const ChallengeDetailScreen({super.key, required this.challenge});

  final EnrichedChallenge challenge;

  /// SharedPreferences key for this challenge's point snapshots.
  String get _trackerKey => 'challenge_${challenge.dto.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildAtomicDetail(context, ref);
  }

  Widget _buildAtomicDetail(BuildContext context, WidgetRef ref) {
    final dto = challenge.dto;

    final progress = ref.watch(
      breakdownProvider.select(
        (s) => s.valueOrNull?.progressForChallenge(dto),
      ),
    );

    final l10n = AppLocalizations.of(context);
    final labels = challengePresentationLabels(l10n);
    final activeAddress = ref.watch(activeAccountProvider).valueOrNull?.address;
    final copyableValues = _challengeCopyableValues(
      address: activeAddress,
      l10n: l10n,
    );

    final breakdown = ref.watch(breakdownProvider).valueOrNull;
    final eb = isProduceBlocksChallenge(dto)
        ? breakdown?.eventBreakdown ??
            breakdown?.seasonBreakdown?.events
                .firstWhereOrNull((e) => e.eventId == dto.eventId)
        : null;
    final card = mapToAtomicCard(
      challenge,
      progress: progress,
      technicalSuccessRate: eb?.successRate,
      labels: labels,
    );
    final dateText = formatDateRange(dto.scheduleStart, dto.scheduleEnd);
    final description = _resolveChallengeDetailText(
      _nonEmpty(dto.description),
      walletAddress: activeAddress,
    );
    final task = _resolveChallengeDetailText(
      _nonEmpty(dto.task),
      walletAddress: activeAddress,
    );
    final progressHelperText = _progressHelperText(
      progress: progress,
      title: dto.goal,
      description: description,
      task: task,
      leftText: card.leftText,
      rightText: card.rightText,
    );

    AtomicChallengeDetailPage buildPage(
      AtomicChallengeTechnicalHeroCardData? heroCard,
    ) {
      final hasCta = hasChallengeCta(dto);
      return AtomicChallengeDetailPage(
        title: dto.goal,
        description: description ?? '',
        task: task != description ? task : null,
        leftText: card.leftText,
        rightText: card.rightText,
        progressHelperText: progressHelperText,
        heroCard: heroCard,
        phase: card.phase,
        fill: card.fill,
        railTreatment: card.railTreatment,
        dateText: dateText.isNotEmpty ? dateText : l10n.challengeAvailableNow,
        pointsLogic: (dto.rewardLogic?.isNotEmpty ?? false)
            ? _resolveChallengeDetailText(
                  dto.rewardLogic,
                  walletAddress: activeAddress,
                ) ??
                dto.rewardLogic!
            : l10n.challengeDefaultPointsLogic,
        ctaLabel: hasCta
            ? ((dto.ctaLabel?.isNotEmpty ?? false)
                ? dto.ctaLabel!
                : l10n.challengeDefaultCta)
            : null,
        rules: _resolveChallengeDetailText(
          dto.requirements,
          walletAddress: activeAddress,
        ),
        copyableValues: copyableValues,
        labels: atomicChallengeDetailLabels(l10n),
        onCopyableValueTap: (value) {
          Clipboard.setData(ClipboardData(text: value.value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.walletAddressCopied)),
          );
        },
        onBackTap: () {
          if (context.canPop()) context.pop();
        },
        onCtaTap: hasCta ? () => handleChallengeCta(context, dto) : null,
      );
    }

    if (!isProduceBlocksChallenge(dto)) return buildPage(null);

    // Season-scoped breakdown: find the EventBreakdown matching this
    // challenge's event for bonus fields (top3, firstBlock, success50%).
    final blocksSummary = ref.watch(producedBlocksSummaryProvider);
    final nodeStatus = ref.watch(nodeStatusProvider).asData?.value;
    final latestEpoch = nodeStatus?.currentEpoch;

    // Record point snapshot on each successful data load. Skip zero because
    // the aggregator may not have tallied yet, which would skew the diff.
    if (challenge.earnedPoints != null && challenge.earnedPoints! > 0) {
      ChallengePointTracker.record(_trackerKey, challenge.earnedPoints!);
    }

    return FutureBuilder<PointDiff?>(
      future: ChallengePointTracker.getDiffBestEffort(_trackerKey),
      builder: (context, diffSnapshot) {
        return buildPage(
          _buildProduceBlocksHeroCard(
            context,
            ref,
            eb,
            diffSnapshot.data,
            latestEpoch,
            nodeStatus,
            blocksSummary.asData?.value,
          ),
        );
      },
    );
  }

  AtomicChallengeTechnicalHeroCardData _buildProduceBlocksHeroCard(
    BuildContext context,
    WidgetRef ref,
    EventBreakdown? eb,
    PointDiff? diff,
    int? latestEpoch,
    NodeStatusState? nodeStatus,
    ProducedBlocksSummary? blocksSummaryData,
  ) {
    final dto = challenge.dto;
    final l10n = AppLocalizations.of(context);
    final successRate = eb?.successRate ?? 0;

    final ceiling = parseRewardCeiling(formatRewardText(dto.reward));
    final maxPts = ceiling != null ? ceiling - kTop3RankBonusPoints : 0;

    // Prefer the server's per-challenge activities sum; challenge.earnedPoints
    // only reflects the primary breakdown activity and under-counts
    // multi-activity challenges.
    final earnedPoints = challenge.displayEarnedPoints;
    final basePoints = challenge.activity?.points;
    final extraPointsTotal = challenge.extraPoints;
    final isSyncing = isProduceBlocksSyncing(
      isProduceBlocks: true,
      earnedPoints: basePoints,
      successRate: successRate,
    );
    final syncingText = isSyncing
        ? ref.watch(syncingTextProvider).valueOrNull ?? kSyncingTextFallback
        : null;

    final displayBasePoints =
        syncingText ?? (basePoints != null ? formatPoints(basePoints) : '--');
    final totalWithBonuses = (earnedPoints ?? 0) + (eb?.totalBonusPoints ?? 0);
    final displayTotalEarned = syncingText ??
        (earnedPoints != null ? formatPoints(totalWithBonuses) : '--');

    final String? epochEarned;
    final String? epochSectionLabel;
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

    final formula = syncingText == null
        ? AtomicChallengeHeroFormula(
            rateLabel: 'Success rate',
            rateValue: '${successRate.round()}%',
            maxLabel: 'Assigned slots',
            maxValue: formatPoints(maxPts),
            totalLabel: 'Base reward',
            totalValue: displayBasePoints,
          )
        : null;

    final rankLabel = formatRankOrdinal(eb?.rank);
    final rewardLines = <AtomicChallengeHeroRewardLine>[
      AtomicChallengeHeroRewardLine(
        label: epochSectionLabel ?? l10n.challengeEpochLast24h,
        value: epochEarned ?? l10n.challengeEpochNoChange,
      ),
    ];

    if ((eb?.top3Points ?? 0) > 0 || rankLabel != null) {
      rewardLines.insert(
        0,
        AtomicChallengeHeroRewardLine(
          label: 'Top 3 rank reward',
          badge: rankLabel,
          value: '+${formatPoints(eb?.top3Points ?? 0)}',
        ),
      );
    }

    if (extraPointsTotal > 0) {
      rewardLines.add(
        AtomicChallengeHeroRewardLine(
          label: 'Extra points',
          value: '+${formatPoints(extraPointsTotal)}',
        ),
      );
    }
    if ((eb?.firstBlockPoints ?? 0) > 0) {
      rewardLines.add(
        AtomicChallengeHeroRewardLine(
          label: 'First block reward',
          value: '+${formatPoints(eb!.firstBlockPoints!)}',
        ),
      );
    }
    if ((eb?.success50PercentPoints ?? 0) > 0) {
      rewardLines.add(
        AtomicChallengeHeroRewardLine(
          label: '50% success reward',
          value: '+${formatPoints(eb!.success50PercentPoints!)}',
        ),
      );
    }

    return AtomicChallengeTechnicalHeroCardData(
      totalEarned: displayTotalEarned,
      totalUnit: syncingText == null ? 'pts' : null,
      formula: formula,
      rewardLines: rewardLines,
      epochLabel: latestEpoch != null ? 'View epoch $latestEpoch slots' : null,
      onEpochTap: latestEpoch != null && blocksSummaryData != null
          ? () => _navigateToSlots(context, blocksSummaryData, latestEpoch, [
                'all',
              ])
          : null,
      overview: _buildStatusOverview(
        context,
        ref,
        nodeStatus,
        blocksSummaryData,
        latestEpoch,
      ),
    );
  }

  List<AtomicChallengeHeroOverviewItem> _buildStatusOverview(
    BuildContext context,
    WidgetRef ref,
    NodeStatusState? nodeStatus,
    ProducedBlocksSummary? summary,
    int? currentEpoch,
  ) {
    void networkOnTap() {
      // Node status is its own pushed route now (SV shell owns home).
      context.push(AppRoutes.mainNode);
    }

    final AtomicChallengeHeroOverviewItem networkStep;
    if (nodeStatus == null) {
      networkStep = AtomicChallengeHeroOverviewItem(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        value: 'Loading',
        onTap: networkOnTap,
      );
    } else if (nodeStatus.connectedPeers > 0) {
      networkStep = AtomicChallengeHeroOverviewItem(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        value: 'Connected',
        tone: AtomicChallengeHeroOverviewTone.success,
        onTap: networkOnTap,
      );
    } else {
      networkStep = AtomicChallengeHeroOverviewItem(
        label: 'Network',
        icon: Symbols.wifi_sharp,
        value: 'Disconnected',
        tone: AtomicChallengeHeroOverviewTone.error,
        onTap: networkOnTap,
      );
    }

    final vrfStatus = nodeStatus?.vrfEvaluator?.currentEpochVrfEvaluationStatus;
    final vrfValue = switch (vrfStatus) {
      RpcStatusVrfEvaluationStatus.completed => 'Complete',
      RpcStatusVrfEvaluationStatus.evaluating => 'Evaluating',
      RpcStatusVrfEvaluationStatus.pending => 'Pending',
      null => 'Unknown',
    };
    final vrfTone = switch (vrfStatus) {
      RpcStatusVrfEvaluationStatus.completed =>
        AtomicChallengeHeroOverviewTone.success,
      RpcStatusVrfEvaluationStatus.evaluating =>
        AtomicChallengeHeroOverviewTone.info,
      RpcStatusVrfEvaluationStatus.pending ||
      null =>
        AtomicChallengeHeroOverviewTone.neutral,
    };
    final vrfStep = AtomicChallengeHeroOverviewItem(
      label: 'VRF Calculation',
      icon: Symbols.casino_sharp,
      value: vrfValue,
      tone: vrfTone,
      onTap: currentEpoch != null && summary != null
          ? () => _navigateToSlots(context, summary, currentEpoch, ['all'])
          : null,
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    String? nextBlockText;

    if (summary != null) {
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

    final AtomicChallengeHeroOverviewItem nextBlockStep;
    final hasUpcoming = nextBlockText != null;
    if (hasUpcoming) {
      nextBlockStep = AtomicChallengeHeroOverviewItem(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        value: nextBlockText,
        tone: AtomicChallengeHeroOverviewTone.info,
        onTap: summary != null
            ? () =>
                _navigateToSlots(context, summary, currentEpoch, ['upcoming'])
            : null,
      );
    } else if (vrfStatus == RpcStatusVrfEvaluationStatus.completed) {
      nextBlockStep = const AtomicChallengeHeroOverviewItem(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        value: 'None this epoch',
      );
    } else {
      nextBlockStep = const AtomicChallengeHeroOverviewItem(
        label: 'Next Block',
        icon: Symbols.schedule_sharp,
        value: 'Waiting for VRF',
      );
    }

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
            break;
          }
        }
        if (lastProducedTimeMs != null) break;
      }
    }

    final AtomicChallengeHeroOverviewItem lastProducedStep;
    if (lastProducedTimeMs != null) {
      final agoMs = nowMs - lastProducedTimeMs.toInt();
      lastProducedStep = AtomicChallengeHeroOverviewItem(
        label: 'Last Produced',
        icon: Symbols.check_circle_sharp,
        value: _formatTimeAgo(agoMs),
        tone: AtomicChallengeHeroOverviewTone.success,
        onTap: summary != null
            ? () =>
                _navigateToSlots(context, summary, currentEpoch, ['produced'])
            : null,
      );
    } else {
      lastProducedStep = const AtomicChallengeHeroOverviewItem(
        label: 'Last Produced',
        icon: Symbols.check_circle_sharp,
        value: 'None yet',
      );
    }

    final AtomicChallengeHeroOverviewItem missedBlocksStep;
    if (summary != null && currentEpoch != null) {
      final currentScore =
          (currentEpoch >= 0 && currentEpoch < summary.epochScores.length)
              ? summary.epochScores[currentEpoch]
              : null;
      final missed = currentScore?.missed ?? 0;
      missedBlocksStep = AtomicChallengeHeroOverviewItem(
        label: 'Missed Blocks',
        icon: Symbols.disabled_by_default_sharp,
        value:
            missed > 0 ? '$missed ${missed == 1 ? 'block' : 'blocks'}' : 'None',
        tone: missed > 0
            ? AtomicChallengeHeroOverviewTone.warning
            : AtomicChallengeHeroOverviewTone.success,
        onTap: missed > 0
            ? () => _navigateToSlots(context, summary, currentEpoch, ['missed'])
            : null,
      );
    } else {
      missedBlocksStep = const AtomicChallengeHeroOverviewItem(
        label: 'Missed Blocks',
        icon: Symbols.disabled_by_default_sharp,
        value: 'Loading',
      );
    }

    return [
      networkStep,
      vrfStep,
      nextBlockStep,
      lastProducedStep,
      missedBlocksStep,
    ];
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
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

List<AtomicChallengeCopyableValue> _challengeCopyableValues({
  required String? address,
  required AppLocalizations l10n,
}) {
  final value = address?.trim();
  if (value == null || value.isEmpty) return const [];

  return [
    AtomicChallengeCopyableValue(
      label: l10n.walletMyAddress,
      value: value,
      displayValue: Utils.shortenID(value, head: 6, tail: 6),
      tooltip: l10n.walletCopyAddress,
    ),
  ];
}

String? _resolveChallengeDetailText(
  String? value, {
  required String? walletAddress,
}) {
  final text = _nonEmpty(value);
  final address = walletAddress?.trim();
  if (text == null || address == null || address.isEmpty) return text;

  // Supported mobile challenge-copy tags:
  // - {{ user.wallet_address }}
  // - {{ user.walletAddress }}
  //
  // Keep this intentionally narrow until the backend exposes a proper
  // participant/profile templating contract. The resolved wallet text is also
  // passed to AtomicChallengeDetailPage as a copyable inline value.
  return text.replaceAll(
    RegExp(r'\{\{\s*user\.(wallet_address|walletAddress)\s*\}\}'),
    address,
  );
}

String? _progressHelperText({
  required ChallengeProgress? progress,
  required String title,
  required String? description,
  required String? task,
  required String leftText,
  required String rightText,
}) {
  final text = _nonEmpty(progress?.description);
  if (progress == null || text == null) return null;

  final normalized = _normalizeForComparison(text);
  final duplicateSources = [
    title,
    description,
    task,
    leftText,
    rightText,
  ].map(_normalizeForComparison);
  if (duplicateSources.contains(normalized)) return null;

  final hasMeaningfulProgress = progress.state != ChallengeProgressState.none ||
      progress.current != null ||
      progress.pendingPoints > 0 ||
      progress.earnedPoints > 0;
  if (!hasMeaningfulProgress) return null;

  return text;
}

String _normalizeForComparison(String? value) =>
    value?.trim().toLowerCase() ?? '';
