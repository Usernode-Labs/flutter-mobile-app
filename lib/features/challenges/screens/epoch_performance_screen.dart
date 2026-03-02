import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Feature screen that wires live block-production data to
/// [EpochPerformancePage].
///
/// Navigated to from the "View Epoch" CTA in the challenge detail page.
/// Receives an [initialEpoch] from the route extra.
class EpochPerformanceScreen extends ConsumerStatefulWidget {
  const EpochPerformanceScreen({super.key, required this.initialEpoch});

  final int initialEpoch;

  @override
  ConsumerState<EpochPerformanceScreen> createState() =>
      _EpochPerformanceScreenState();
}

class _EpochPerformanceScreenState
    extends ConsumerState<EpochPerformanceScreen> {
  late int _viewedEpoch;

  @override
  void initState() {
    super.initState();
    _viewedEpoch = widget.initialEpoch;
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(producedBlocksSummaryProvider);
    final nodeStatus = ref.watch(nodeStatusProvider).value;
    final l10n = AppLocalizations.of(context);

    final dataValue = summary.asData?.value;
    final currentEpoch = dataValue?.currentEpoch ?? 0;
    final maxEpochWithData = dataValue?.maxEpochWithData ?? currentEpoch;
    final viewedEpoch = _viewedEpoch.clamp(0, maxEpochWithData);

    return summary.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Symbols.arrow_back_sharp),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.statsEpoch(_viewedEpoch)),
        ),
        body: const FullPageLoadingState(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Symbols.arrow_back_sharp),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.statsEpoch(_viewedEpoch)),
        ),
        body: FullPageErrorState(
          message: l10n.commonNoValuePlaceholder,
        ),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(producedBlocksSummaryProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: _buildPage(
              context,
              data,
              nodeStatus,
              viewedEpoch,
              currentEpoch,
              maxEpochWithData,
              l10n,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    ProducedBlocksSummary data,
    NodeStatusState? nodeStatus,
    int viewedEpoch,
    int currentEpoch,
    int maxEpochWithData,
    AppLocalizations l10n,
  ) {
    // Epoch progress computation
    final totalSlots = data.slotsInEpoch;
    final isCurrentViewed = viewedEpoch == currentEpoch;
    final isFutureViewed = viewedEpoch > currentEpoch;

    int currSlot;
    double progressValue;
    if (totalSlots <= 0) {
      currSlot = 0;
      progressValue = 0.0;
    } else if (isCurrentViewed) {
      currSlot = data.currentEpochSlot;
      progressValue = currSlot / totalSlots;
    } else if (isFutureViewed) {
      currSlot = 0;
      progressValue = 0.0;
    } else {
      currSlot = totalSlots;
      progressValue = 1.0;
    }

    // Time left label
    String rightLabel;
    if (isCurrentViewed) {
      final slotMs = nodeStatus?.slotDurationMs ?? 0;
      final remainingSlots = totalSlots - data.currentEpochSlot;
      final clampedRemaining = remainingSlots < 0 ? 0 : remainingSlots;
      final timeLeft = slotMs > 0
          ? Duration(milliseconds: clampedRemaining * slotMs)
          : Duration.zero;
      final hours = timeLeft.inHours;
      final minutes = timeLeft.inMinutes.remainder(60);
      rightLabel = timeLeft == Duration.zero
          ? l10n.producedBlocksZeroMinutesLeft
          : (hours > 0
              ? l10n.producedBlocksHoursMinutesLeft(hours, minutes)
              : l10n.producedBlocksMinutesLeft(minutes));
    } else {
      rightLabel = l10n.commonEmDash;
    }

    // Epoch score
    final scores = data.epochScores;
    final idx = (viewedEpoch >= 0 && viewedEpoch < scores.length)
        ? viewedEpoch
        : (scores.isNotEmpty ? scores.length - 1 : -1);
    final score = idx >= 0 ? scores[idx] : null;

    final epochPerf = _computePerformance(score);
    final perfStr =
        epochPerf != null ? '${(epochPerf * 100).toStringAsFixed(1)}%' : '--';

    return EpochPerformancePage(
      epochLabel: l10n.statsEpoch(viewedEpoch),
      progress: progressValue,
      progressLeftLabel: l10n.producedBlocksEpochSlotProgress(
        currSlot,
        totalSlots,
      ),
      progressRightLabel: rightLabel,
      performanceLabel: l10n.producedBlocksEpochPerformance,
      performanceValue: perfStr,
      metrics: _buildMetrics(context, data, viewedEpoch, currentEpoch, l10n),
      onPrev: viewedEpoch > 0
          ? () => setState(() => _viewedEpoch = viewedEpoch - 1)
          : null,
      onNext: viewedEpoch < maxEpochWithData
          ? () => setState(() => _viewedEpoch = viewedEpoch + 1)
          : null,
      onPickEpoch: (e) => setState(() => _viewedEpoch = e),
      maxEpoch: maxEpochWithData,
      selectedEpoch: viewedEpoch,
      epochScoreLookup: (epoch) {
        if (epoch < 0 || epoch >= scores.length) return '';
        final perf = _computePerformance(scores[epoch]);
        return perf != null ? '${(perf * 100).toStringAsFixed(0)}%' : '';
      },
      onBackTap: () => context.pop(),
    );
  }

  List<EpochMetricData> _buildMetrics(
    BuildContext context,
    ProducedBlocksSummary data,
    int viewedEpoch,
    int currentEpoch,
    AppLocalizations l10n,
  ) {
    final scores = data.epochScores;
    final idx = (viewedEpoch >= 0 && viewedEpoch < scores.length)
        ? viewedEpoch
        : (scores.isNotEmpty ? scores.length - 1 : -1);
    final score = idx >= 0 ? scores[idx] : null;
    final slotsInEpoch = data.slotsInEpoch;

    // Checked Slots
    final evaluated = score?.calculated ?? 0;
    final evaluatedPct =
        slotsInEpoch > 0 ? (evaluated / slotsInEpoch) * 100.0 : 0.0;

    // Produced Blocks
    final produced = score?.produced ?? 0;
    final won = score?.won ?? 0;

    // Missed Blocks
    final missed = score?.missed ?? 0;

    // Upcoming Blocks
    final upcoming = score?.upcoming ?? 0;
    final showUpcoming =
        viewedEpoch >= currentEpoch && viewedEpoch <= data.maxEpochWithData;

    final metrics = <EpochMetricData>[
      EpochMetricData(
        icon: Symbols.search_sharp,
        title: l10n.producedBlocksCheckedSlots,
        subtitle: l10n.producedBlocksEvaluatedOfSlots(evaluated, slotsInEpoch),
        trailingValue: '${evaluatedPct.toStringAsFixed(0)}%',
        onTap: () => _navigateToSlots(
          context,
          data,
          score,
          viewedEpoch,
          ['all'],
        ),
        showChevron: true,
      ),
      EpochMetricData(
        icon: Symbols.check_box_sharp,
        title: l10n.producedBlocksTitle,
        subtitle: l10n.producedBlocksProducedOfWon(
          produced.toString(),
          won.toString(),
        ),
        trailingValue: '$produced',
        onTap: produced > 0
            ? () => _navigateToSlots(
                  context,
                  data,
                  score,
                  viewedEpoch,
                  ['produced'],
                )
            : null,
        showChevron: produced > 0,
      ),
      EpochMetricData(
        icon: Symbols.disabled_by_default_sharp,
        title: l10n.producedBlocksMissedBlocksTitle,
        subtitle: l10n.producedBlocksMissedOfWon(
          missed.toString(),
          won.toString(),
        ),
        trailingValue: '$missed',
        onTap: missed > 0
            ? () => _navigateToSlots(
                  context,
                  data,
                  score,
                  viewedEpoch,
                  ['missed'],
                )
            : null,
        showChevron: missed > 0,
      ),
    ];

    if (showUpcoming) {
      metrics.add(
        EpochMetricData(
          icon: Symbols.schedule_sharp,
          title: l10n.producedBlocksUpcomingBlocksTitle,
          subtitle: l10n.producedBlocksUpcomingThisEpoch(upcoming.toString()),
          trailingValue: '$upcoming',
          onTap: upcoming > 0
              ? () => _navigateToSlots(
                    context,
                    data,
                    score,
                    viewedEpoch,
                    ['upcoming'],
                  )
              : null,
          showChevron: upcoming > 0,
        ),
      );
    }

    return metrics;
  }

  /// Navigate to slot assignments with extracted slot data.
  void _navigateToSlots(
    BuildContext context,
    ProducedBlocksSummary data,
    EpochScore? score,
    int epoch,
    List<String> filters,
  ) {
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
            .map((s) => s.producedBlockMetadata == null
                ? null
                : <String, dynamic>{
                    'blockHash': s.producedBlockMetadata!.blockHash.toString(),
                    'canonical': s.producedBlockMetadata!.canonical,
                    'timestampMs':
                        s.producedBlockMetadata!.timestampMs.toString(),
                    'tokensWon': s.producedBlockMetadata!.tokensWon.toString(),
                  })
            .toList();

    context.push(
      AppRoutes.slotAssignments,
      extra: {
        'epoch': epoch,
        'slotsInEpoch': data.slotsInEpoch,
        'results': results,
        'slotTimesMs': slotTimesMs,
        'producedMeta': producedMeta,
        'filters': filters,
      },
    );
  }

  double? _computePerformance(EpochScore? score) {
    if (score == null) return null;
    final value = score.evaluatedPercent * score.producedOfEvaluatedPercent;
    if (value.isNaN || value.isInfinite) return null;
    return value.clamp(0.0, 1.0);
  }
}
