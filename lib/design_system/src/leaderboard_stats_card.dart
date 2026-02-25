import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

/// A stats summary card with distribution chart for the leaderboard page.
///
/// Composes two private sub-widgets:
/// - `_StatBox` — bordered container with uppercase label + monospace value
/// - `_DistributionChart` — widget-based bar chart with tooltip
///
/// Presentation-only — takes all state via constructor params.
class LeaderboardStatsCard extends StatelessWidget {
  const LeaderboardStatsCard({
    super.key,
    required this.totalPoints,
    required this.totalPointsLabel,
    required this.rank,
    required this.rankLabel,
    required this.distribution,
    required this.userBarIndex,
    this.tooltipText,
  });

  /// The total points value, e.g. "18,000".
  final String totalPoints;

  /// Label above total points, e.g. "TOTAL POINTS".
  final String totalPointsLabel;

  /// The rank value, e.g. "34".
  final String rank;

  /// Label above rank, e.g. "RANK".
  final String rankLabel;

  /// Normalized bar heights (0..1). Length determines bar count.
  final List<double> distribution;

  /// Which bar is the user's (highlighted).
  final int userBarIndex;

  /// Optional tooltip text above the chart.
  final String? tooltipText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: totalPointsLabel,
                  value: totalPoints,
                ),
              ),
              SizedBox(width: spacing.space8),
              Expanded(
                child: _StatBox(
                  label: rankLabel,
                  value: rank,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.space16),
          _DistributionChart(
            distribution: distribution,
            userBarIndex: userBarIndex,
            tooltipText: tooltipText,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatBox — bordered container with uppercase label + monospace value
// ---------------------------------------------------------------------------

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      padding: EdgeInsets.all(spacing.space24),
      decoration: BoxDecoration(
        borderRadius: radii.borderRadiusLarge,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space4),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontFamily: 'IBMPlexMono',
              color: colors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DistributionChart — widget-based bar chart with tooltip
// ---------------------------------------------------------------------------

class _DistributionChart extends StatefulWidget {
  const _DistributionChart({
    required this.distribution,
    required this.userBarIndex,
    this.tooltipText,
  });

  final List<double> distribution;
  final int userBarIndex;
  final String? tooltipText;

  @override
  State<_DistributionChart> createState() => _DistributionChartState();
}

class _DistributionChartState extends State<_DistributionChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _chartHeight = 120.0;
  static const _minBarFraction = 4.0 / _chartHeight;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static double _barProgress(int i, int n, double t) {
    final start = i / n;
    final end = (i + 1.5) / n;
    return Curves.easeOutCubic.transform(
      ((t - start) / (end - start)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (widget.distribution.isEmpty) return const SizedBox.shrink();

    final hasTooltip =
        widget.tooltipText != null && widget.tooltipText!.isNotEmpty;
    final clampedIndex =
        widget.userBarIndex.clamp(0, widget.distribution.length - 1);
    final community = semantic.community;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip
        if (hasTooltip)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.space4),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space8,
                vertical: spacing.space4,
              ),
              decoration: BoxDecoration(
                color: community.color,
                borderRadius: radii.borderRadiusSmall,
              ),
              child: Text(
                widget.tooltipText!,
                style: textTheme.labelSmall?.copyWith(
                  color: community.onColor,
                ),
              ),
            ),
          ),

        // Bars
        SizedBox(
          height: _chartHeight,
          child: reduceMotion
              ? _buildBars(
                  colors: colors,
                  community: community,
                  spacing: spacing,
                  radii: radii,
                  clampedIndex: clampedIndex,
                  animationValue: 1.0,
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _buildBars(
                    colors: colors,
                    community: community,
                    spacing: spacing,
                    radii: radii,
                    clampedIndex: clampedIndex,
                    animationValue: _controller.value,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBars({
    required ColorScheme colors,
    required SemanticColorGroup community,
    required AppSpacing spacing,
    required AppRadii radii,
    required int clampedIndex,
    required double animationValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: spacing.space4,
      children: [
        for (var i = 0; i < widget.distribution.length; i++)
          Expanded(
            child: FractionallySizedBox(
              heightFactor: widget.distribution[i].clamp(_minBarFraction, 1.0) *
                  (animationValue >= 1.0
                      ? 1.0
                      : _barProgress(
                          i,
                          widget.distribution.length,
                          animationValue,
                        )),
              alignment: Alignment.bottomCenter,
              child: Container(
                decoration: BoxDecoration(
                  color: i < clampedIndex
                      ? community.colorContainer
                      : i == clampedIndex
                          ? community.color
                          : colors.outlineVariant,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radii.small / 2),
                  ),
                  boxShadow: i == clampedIndex
                      ? [
                          BoxShadow(
                            color: community.color.withValues(alpha: 0.35),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
