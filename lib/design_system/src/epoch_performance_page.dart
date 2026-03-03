import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/widgets/app_progress_bar.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'icon_badge.dart';
import 'sheet_layout.dart';
import 'text_chevron_trailing.dart';

/// Data for a single metric row in [EpochPerformancePage].
class EpochMetricData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailingValue;
  final VoidCallback? onTap;
  final bool showChevron;

  const EpochMetricData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailingValue,
    this.onTap,
    this.showChevron = false,
  });
}

/// A full-page epoch performance view showing epoch progress and metric tiles.
///
/// Presentation-only: all data comes through constructor parameters.
/// The feature screen in `lib/features/` wires state to this widget.
class EpochPerformancePage extends StatelessWidget {
  const EpochPerformancePage({
    super.key,
    required this.epochLabel,
    required this.progress,
    required this.progressLeftLabel,
    required this.progressRightLabel,
    required this.performanceLabel,
    required this.performanceValue,
    required this.metrics,
    this.onPrev,
    this.onNext,
    required this.onPickEpoch,
    required this.maxEpoch,
    required this.selectedEpoch,
    this.epochScoreLookup,
    this.onBackTap,
  });

  /// Epoch title, e.g. "Epoch 176".
  final String epochLabel;

  /// Progress fraction (0.0–1.0) for the epoch progress bar.
  final double progress;

  /// Left label below progress bar, e.g. "12,000 / 17,280 slots".
  final String progressLeftLabel;

  /// Right label below progress bar, e.g. "7h 14min left".
  final String progressRightLabel;

  /// Label for the performance heading row, e.g. "Epoch Performance".
  final String performanceLabel;

  /// Value for the performance heading row, e.g. "95.2%".
  final String performanceValue;

  /// Metric rows (Checked Slots, Produced Blocks, Missed, Upcoming).
  final List<EpochMetricData> metrics;

  /// Navigate to previous epoch.
  final VoidCallback? onPrev;

  /// Navigate to next epoch.
  final VoidCallback? onNext;

  /// Called when user picks an epoch from the picker.
  final ValueChanged<int> onPickEpoch;

  /// Maximum epoch number available.
  final int maxEpoch;

  /// Currently selected epoch number.
  final int selectedEpoch;

  /// Lookup function returning performance string for a given epoch.
  /// Used in the epoch picker bottom sheet.
  final String Function(int epoch)? epochScoreLookup;

  /// Called when the back button is tapped.
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      appBar: AppBar(
        leading: onBackTap != null
            ? IconButton(
                icon: const Icon(Symbols.arrow_back_sharp),
                onPressed: onBackTap,
              )
            : null,
        title: Text(epochLabel),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: spacing.space8),
            // "All" filter chip
            Wrap(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: true,
                  onSelected: (_) {},
                ),
              ],
            ),
            SizedBox(height: spacing.space16),
            // Epoch panel
            _EpochPanel(
              epochLabel: epochLabel,
              progress: progress,
              progressLeftLabel: progressLeftLabel,
              progressRightLabel: progressRightLabel,
              onPrev: onPrev,
              onNext: onNext,
              maxEpoch: maxEpoch,
              selectedEpoch: selectedEpoch,
              onPickEpoch: onPickEpoch,
              epochScoreLookup: epochScoreLookup,
            ),
            SizedBox(height: spacing.space24),
            // Performance heading
            _PerformanceHeading(
              label: performanceLabel,
              value: performanceValue,
            ),
            SizedBox(height: spacing.space8),
            // Metric tiles
            ...metrics.map((m) => _buildMetricTile(context, m)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, EpochMetricData metric) {
    return ListTile(
      leading: IconBadge(icon: metric.icon),
      title: Text(metric.title),
      subtitle: Text(metric.subtitle),
      trailing: metric.showChevron
          ? TextChevronTrailing(text: metric.trailingValue)
          : Text(metric.trailingValue),
      onTap: metric.onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

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
    this.epochScoreLookup,
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
  final String Function(int epoch)? epochScoreLookup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: radii.borderRadiusSmall,
                onTap: () => _showEpochPicker(context),
                child: Row(
                  children: [
                    Text(
                      epochLabel,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: spacing.space4),
                    Icon(Symbols.expand_more_sharp, size: sizing.iconXSmall),
                  ],
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: onPrev,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.all(spacing.space8),
                minimumSize:
                    Size(sizing.iconContainerSmall, sizing.iconContainerSmall),
              ),
              icon: const Icon(Symbols.chevron_left_sharp),
            ),
            SizedBox(width: spacing.space8),
            IconButton.filledTonal(
              onPressed: onNext,
              style: IconButton.styleFrom(
                shape: const CircleBorder(),
                padding: EdgeInsets.all(spacing.space8),
                minimumSize:
                    Size(sizing.iconContainerSmall, sizing.iconContainerSmall),
              ),
              icon: const Icon(Symbols.chevron_right_sharp),
            ),
          ],
        ),
        SizedBox(height: spacing.space8),
        AppProgressBar(value: progress),
        SizedBox(height: spacing.space4),
        Row(
          children: [
            Expanded(
              child: Text(
                progressLeftLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              progressRightLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEpochPicker(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: height * 0.6),
      builder: (ctx) {
        return SheetLayout(
          title: 'Select Epoch',
          child: ListView.builder(
            itemCount: maxEpoch + 1,
            itemBuilder: (_, index) {
              final epoch = maxEpoch - index;
              final selected = epoch == selectedEpoch;
              final score = epochScoreLookup?.call(epoch) ?? '';
              final label = score.isNotEmpty
                  ? 'Epoch $epoch \u00b7 $score'
                  : 'Epoch $epoch';

              return ListTile(
                title: Text(label),
                trailing: selected
                    ? Icon(Symbols.check_sharp,
                        color: theme.colorScheme.onSurface)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  onPickEpoch(epoch);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _PerformanceHeading extends StatelessWidget {
  const _PerformanceHeading({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
