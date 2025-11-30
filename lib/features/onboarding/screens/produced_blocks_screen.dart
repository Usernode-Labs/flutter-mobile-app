import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/features/node/produced_blocks_provider.dart';

class ProducedBlocksScreen extends ConsumerStatefulWidget {
  const ProducedBlocksScreen({super.key});

  @override
  ConsumerState<ProducedBlocksScreen> createState() =>
      _ProducedBlocksScreenState();
}

class _ProducedBlocksScreenState
    extends ConsumerState<ProducedBlocksScreen> {
  int? _viewedEpoch;
  @override
  void reassemble() {
    super.reassemble();
    // Force provider to recompute on hot reload
    ref.invalidate(producedBlocksSummaryProvider);
  }

  double totalScoreLastN(summary, int n) {
    double score = 0.0;
    int total = 0;
    // TODO: need to decide how to handle the current epoch; should probably calculate the partial results
    for (var i = summary.currentEpoch; i > summary.currentEpoch - n && i >= 0; i--) { 
      total += 1;
      if (i >= summary.epochScores.length) {
        continue;
      }
      final evaluatedPercent = summary.epochScores[i].evaluatedPercent;
      final producedOfEvaluatedPercent = summary.epochScores[i].producedOfEvaluatedPercent;
      //print('Epoch $i: Evaluated: $evaluatedPercent, Produced: $producedOfEvaluatedPercent');
      score += (evaluatedPercent * producedOfEvaluatedPercent).clamp(0.0, 1.0);
    }
    return score / total;
  }

  double scoreEpochI(dynamic summary, int i) {
    // print('Epoch $i: Summary: $summary');
    if (summary == null) return 0.0;
    final scores = summary.epochScores;
    if (scores == null || i < 0 || i >= scores.length) return 0.0;
    final s = scores[i];
    // print('Epoch $i: Evaluated: ${s.evaluatedPercent}, Produced: ${s.producedOfEvaluatedPercent}');
    final value = (s.evaluatedPercent * s.producedOfEvaluatedPercent);
    if (value.isNaN || value.isInfinite) return 0.0;
    // print('Epoch $i: Value: $value, clamped: ${value.clamp(0.0, 1.0)}');
    return value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;
    final summary = ref.watch(producedBlocksSummaryProvider);
    final dataValue = summary.asData?.value;
    final currentEpoch = dataValue?.currentEpoch ?? 0;
    final maxEpochWithData = dataValue?.maxEpochWithData ?? currentEpoch;
    final viewedEpoch = (_viewedEpoch != null)
        ? _viewedEpoch!.clamp(0, maxEpochWithData)
        : currentEpoch;

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh node status first so slot progress is up to date,
        // then recompute the produced blocks summary.
        await ref.read(nodeStatusProvider.notifier).refresh();
        // Ensure the summary recomputes with fresh node status.
        final _ = await ref.refresh(producedBlocksSummaryProvider.future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top KPI centered within the top area
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            summary.when(
                              data: (value) => Text(

                                '${(totalScoreLastN(value, 10) * 100).toStringAsFixed(1)}%',
                                style: theme.textTheme.displaySmall,
                                textAlign: TextAlign.center,
                              ),
                              loading: () => const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                              error: (e, _) => Text(
                                '--',
                                style: theme.textTheme.displaySmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Block Success Rate · Last 10 Epochs',
                              style: theme.textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom group: epoch + block production, hugged to bottom
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Builder(builder: (context) {
                          final currEpochSlot = summary.asData?.value.currentEpochSlot;
                          final totalSlots = summary.asData?.value.slotsInEpoch;
                          final isCurrentViewed = viewedEpoch == currentEpoch;
                          final isFutureViewed = viewedEpoch > currentEpoch;

                          int curr;
                          double progressValue;
                          if (totalSlots == null || totalSlots <= 0) {
                            curr = 0;
                            progressValue = 0.0;
                          } else if (isCurrentViewed) {
                            curr = currEpochSlot ?? 0;
                            progressValue = curr / totalSlots;
                          } else if (isFutureViewed) {
                            // Future epoch: no progress yet
                            curr = 0;
                            progressValue = 0.0;
                          } else {
                            // Past epoch: treat as fully complete
                            curr = totalSlots;
                            progressValue = 1.0;
                          }

                          final leftLabel = 'Epoch Slot Progress: $curr / ${(totalSlots ?? 0)}';
                          // Compute time left in epoch only for current epoch
                          final nodeStatus = ref.watch(nodeStatusProvider).value;
                          String rightLabel;
                          if (isCurrentViewed) {
                            final slotMs = nodeStatus?.slotDurationMs ?? 0;
                            final remainingSlots = (totalSlots != null ? (totalSlots - (currEpochSlot ?? 0)) : 0);
                            final clampedRemaining = remainingSlots < 0 ? 0 : remainingSlots;
                            final timeLeft = slotMs > 0
                                ? Duration(milliseconds: clampedRemaining * slotMs)
                                : Duration.zero;
                            final hours = timeLeft.inHours;
                            final minutes = timeLeft.inMinutes.remainder(60);
                            rightLabel = timeLeft == Duration.zero
                                ? '0m left'
                                : (hours > 0 ? '${hours}h ${minutes}m left' : '${minutes}m left');
                          } else {
                            rightLabel = '—';
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _EpochPanel(
                                  epochLabel: 'Epoch $viewedEpoch',
                                  progress: progressValue,
                                  progressLeftLabel: leftLabel,
                                  progressRightLabel: rightLabel,
                                  onPrev: viewedEpoch > 0
                                      ? () {
                                          setState(() {
                                            _viewedEpoch = viewedEpoch - 1;
                                          });
                                        }
                                      : null,
                                  onNext: viewedEpoch < maxEpochWithData
                                      ? () {
                                          setState(() {
                                            _viewedEpoch = viewedEpoch + 1;
                                          });
                                        }
                                      : null,
                                  maxEpoch: maxEpochWithData,
                                  selectedEpoch: viewedEpoch,
                                  onPickEpoch: (e) {
                                    setState(() {
                                      _viewedEpoch = e;
                                    });
                                  },
                                ),
                                const SizedBox(height: 30),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Epoch Performance',
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Text(
                                      '${(scoreEpochI(summary.asData?.value, viewedEpoch) * 100).toStringAsFixed(1)}%',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Builder(builder: (_) {
                                  final data = summary.asData?.value;
                                  final scores = data?.epochScores ?? const [];
                                  final idxCandidate = viewedEpoch;
                                  final idx = (scores.isNotEmpty && idxCandidate < scores.length)
                                      ? idxCandidate
                                      : (scores.isNotEmpty ? scores.length - 1 : -1);
                                  final score = idx >= 0 ? scores[idx] : null;
                                  final slotsInEpoch = data?.slotsInEpoch ?? 0;
                                  final evaluated = score?.calculated ?? 0;
                                  final evaluatedPct = slotsInEpoch > 0 ? (evaluated / slotsInEpoch) * 100.0 : 0.0;
                                  return _MetricTile(
                                    leading: const _IconBadge(icon: Icons.search_outlined),
                                    title: 'Checked Slots',
                                    subtitle: 'Evaluated $evaluated of $slotsInEpoch',
                                    trailingPrimary: '${evaluatedPct.toStringAsFixed(0)}%',
                                    onTap: () {
                                      final epoch = viewedEpoch;
                                      final epochScore = score;
                                      final epochData = epochScore?.epochData.slotData;
                                      final results = epochData == null
                                          ? <int>[]
                                          : epochData.map((s) => s.result.index).toList();
                                      final slotTimesMs = epochData == null
                                          ? <int?>[]
                                          : epochData
                                              .map((s) => s.slotTimeMs == null ? null : (s.slotTimeMs!.toInt()))
                                              .toList();
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
                                          'slotsInEpoch': slotsInEpoch,
                                          'results': results,
                                          'slotTimesMs': slotTimesMs,
                                          'producedMeta': producedMeta,
                                          'filters': ['all'],
                                        },
                                      );
                                    },
                                    showChevron: true,
                                  );
                                }),
                                const SizedBox(height: 6),
                                Builder(builder: (_) {
                                  final data = summary.asData?.value;
                                  final scores = data?.epochScores ?? const [];
                                  final idxCandidate = viewedEpoch;
                                  final idx = (scores.isNotEmpty && idxCandidate < scores.length)
                                      ? idxCandidate
                                      : (scores.isNotEmpty ? scores.length - 1 : -1);
                                  final score = idx >= 0 ? scores[idx] : null;
                                  final produced = score?.produced ?? 0;
                                  final won = score?.won ?? '?';
                                  return _MetricTile(
                                    leading: const _IconBadge(icon: Icons.check_box_outlined),
                                    title: 'Produced Blocks',
                                    subtitle: '$produced of $won produced this epoch',
                                    trailingPrimary: '${produced}',
                                    onTap: produced > 0
                                        ? () {
                                            final epoch = viewedEpoch;
                                            final epochScore = score;
                                            final slotsInEpoch = data?.slotsInEpoch ?? 0;
                                            final epochData = epochScore?.epochData.slotData;
                                            final results = epochData == null
                                                ? <int>[]
                                                : epochData.map((s) => s.result.index).toList();
                                          final slotTimesMs = epochData == null
                                              ? <int?>[]
                                              : epochData
                                                  .map((s) => s.slotTimeMs == null ? null : (s.slotTimeMs!.toInt()))
                                                  .toList();
                                            final producedMeta = epochData == null
                                                ? const <Map<String, dynamic>?>[]
                                                : epochData
                                                    .map((s) => s.producedBlockMetadata == null
                                                        ? null
                                                        : <String, dynamic>{
                                                            'blockHash': s.producedBlockMetadata!.blockHash.toString(),
                                                            'canonical': s.producedBlockMetadata!.canonical,
                                                            'timestampMs': s.producedBlockMetadata!.timestampMs
                                                                .toString(),
                                                            'tokensWon': s.producedBlockMetadata!.tokensWon.toString(),
                                                          })
                                                    .toList();
                                            context.push(
                                              AppRoutes.slotAssignments,
                                              extra: {
                                                'epoch': epoch,
                                                'slotsInEpoch': slotsInEpoch,
                                                'results': results,
                                                'slotTimesMs': slotTimesMs,
                                                'producedMeta': producedMeta,
                                                'filters': ['produced'],
                                              },
                                            );
                                          }
                                        : null,
                                    showChevron: produced > 0,
                                  );
                                }),
                                const SizedBox(height: 6),
                                Builder(builder: (_) {
                                  final data = summary.asData?.value;
                                  final scores = data?.epochScores ?? const [];
                                  final idxCandidate = viewedEpoch;
                                  final idx = (scores.isNotEmpty && idxCandidate < scores.length)
                                      ? idxCandidate
                                      : (scores.isNotEmpty ? scores.length - 1 : -1);
                                  final score = idx >= 0 ? scores[idx] : null;
                                  final missed = score?.missed ?? 0;
                                  final won = score?.won ?? '?';
                                  return _MetricTile(
                                    leading: const _IconBadge(icon: Icons.disabled_by_default_outlined),
                                    title: 'Missed Blocks',
                                    subtitle: '$missed of $won missed this epoch',
                                    trailingPrimary: '$missed',
                                    onTap: missed > 0
                                        ? () {
                                            final epoch = viewedEpoch;
                                            final epochScore = score;
                                            final slotsInEpoch = data?.slotsInEpoch ?? 0;
                                            final epochData = epochScore?.epochData.slotData;
                                            final results = epochData == null
                                                ? <int>[]
                                                : epochData.map((s) => s.result.index).toList();
                                          final slotTimesMs = epochData == null
                                              ? <int?>[]
                                              : epochData
                                                  .map((s) => s.slotTimeMs == null ? null : (s.slotTimeMs!.toInt()))
                                                  .toList();
                                            context.push(
                                              AppRoutes.slotAssignments,
                                              extra: {
                                                'epoch': epoch,
                                                'slotsInEpoch': slotsInEpoch,
                                                'results': results,
                                                'slotTimesMs': slotTimesMs,
                                                'producedMeta': const <Map<String, dynamic>?>[],
                                                'filters': ['missed'],
                                              },
                                            );
                                          }
                                        : null,
                                    showChevron: missed > 0,
                                  );
                                }),
                                const SizedBox(height: 6),
                                (viewedEpoch >= currentEpoch && viewedEpoch <= maxEpochWithData)
                                    ? Builder(builder: (_) {
                                        final data = summary.asData?.value;
                                        final scores = data?.epochScores ?? const [];
                                        final idxCandidate = viewedEpoch;
                                        final idx = (scores.isNotEmpty && idxCandidate < scores.length)
                                            ? idxCandidate
                                            : (scores.isNotEmpty ? scores.length - 1 : -1);
                                        final score = idx >= 0 ? scores[idx] : null;
                                        final upcoming = score?.upcoming ?? 0;
                                        return _MetricTile(
                                          leading: const _IconBadge(icon: Icons.schedule_outlined),
                                          title: 'Upcoming Blocks',
                                          subtitle: '$upcoming upcoming this epoch',
                                          trailingPrimary: '$upcoming',
                                          onTap: upcoming > 0
                                              ? () {
                                                  final epoch = viewedEpoch;
                                                  final epochScore = score;
                                                  final slotsInEpoch = data?.slotsInEpoch ?? 0;
                                                  final epochData = epochScore?.epochData.slotData;
                                                  final results = epochData == null
                                                      ? <int>[]
                                                      : epochData.map((s) => s.result.index).toList();
                                                  final slotTimesMs = epochData == null
                                                      ? <int?>[]
                                                      : epochData
                                                          .map((s) => s.slotTimeMs == null ? null : (s.slotTimeMs!.toInt()))
                                                          .toList();
                                                  context.push(
                                                    AppRoutes.slotAssignments,
                                                    extra: {
                                                      'epoch': epoch,
                                                      'slotsInEpoch': slotsInEpoch,
                                                      'results': results,
                                                      'slotTimesMs': slotTimesMs,
                                                      'producedMeta': const <Map<String, dynamic>?>[],
                                                      'filters': ['upcoming'],
                                                    },
                                                  );
                                                }
                                              : null,
                                          showChevron: upcoming > 0,
                                        );
                                      })
                                    : const SizedBox.shrink(),
                              ],
                            ),
                          );
                        }),
                        (viewedEpoch >= currentEpoch && viewedEpoch <= maxEpochWithData)
                            ? const SizedBox.shrink()
                            : const SizedBox(height: 64),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpochPanel extends StatelessWidget {
  const _EpochPanel({
    required this.epochLabel,
    required this.progress,
    required this.progressLeftLabel,
    required this.progressRightLabel,
    this.onPrev,
    this.onNext,
    required this.maxEpoch,
    required this.selectedEpoch,
    required this.onPickEpoch,
  });

  final String epochLabel;
  final double progress;
  final String progressLeftLabel;
  final String progressRightLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final int maxEpoch;
  final int selectedEpoch;
  final ValueChanged<int> onPickEpoch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = Colors.grey.shade300;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (ctx) {
                      final height = MediaQuery.of(ctx).size.height * 0.6;
                      return SizedBox(
                        height: height,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Select Epoch',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: ListView.builder(
                                itemCount: maxEpoch + 1,
                                reverse: true, // show latest at top
                                itemBuilder: (_, index) {
                                  // When reversed, index 0 corresponds to maxEpoch
                                  final epoch = maxEpoch - index;
                                  final selected = epoch == selectedEpoch;
                                  return ListTile(
                                    title: Text('Epoch $epoch'),
                                    trailing: selected ? const Icon(Icons.check, color: Colors.black87) : null,
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      onPickEpoch(epoch);
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: Row(
                  children: [
                    Text(
                      epochLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
            // Prev / Next circle buttons
            IconButton.filledTonal(
              onPressed: onPrev,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onNext,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 4,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                progressLeftLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            Text(
              progressRightLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailingPrimary,
    this.onTap,
    this.showChevron = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String trailingPrimary;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingPrimary,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(icon, color: theme.colorScheme.onSurface),
      ),
    );
  }
}


