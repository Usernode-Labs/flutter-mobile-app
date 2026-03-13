import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_spacing.dart';
import 'dropdown_sheet.dart';
import 'icon_badge.dart';
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
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      appBar: AppBar(
        leading: onBackTap != null
            ? IconButton(
                icon: const Icon(Symbols.arrow_back_sharp),
                onPressed: onBackTap,
              )
            : null,
        title: GestureDetector(
          onTap: () => _showEpochPicker(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(epochLabel),
              const Icon(Symbols.unfold_more_sharp),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.space16),
          // Performance heading — macro zone (screen margins)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: _PerformanceHeading(
              label: performanceLabel,
              value: performanceValue,
            ),
          ),
          SizedBox(height: spacing.space8),
          // Progress bar + labels — macro zone
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space16),
            child: Column(
              children: [
                LinearProgressIndicator(value: progress),
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
            ),
          ),
          SizedBox(height: spacing.space16),
          // Metric tiles — micro zone (ListTile owns its own contentPadding)
          ...metrics.map((m) => _buildMetricTile(context, m)),
        ],
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

  Future<void> _showEpochPicker(BuildContext context) async {
    final labels = List.generate(maxEpoch + 1, (index) {
      final epoch = maxEpoch - index;
      final score = epochScoreLookup?.call(epoch) ?? '';
      return score.isNotEmpty ? 'Epoch $epoch \u00b7 $score' : 'Epoch $epoch';
    });

    final result = await showDropdownSheet(
      context: context,
      labels: labels,
      title: 'Select Epoch',
      selectedIndex: maxEpoch - selectedEpoch,
    );

    if (result != null) {
      onPickEpoch(maxEpoch - result);
    }
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

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
            style: theme.textTheme.titleMedium,
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
