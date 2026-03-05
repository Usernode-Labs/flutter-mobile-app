import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A stats summary card with dot-matrix distribution chart for the leaderboard.
///
/// Composes three private sub-widgets:
/// - `_StatBox` — bordered container with uppercase label + monospace value
/// - `_DotMatrixChart` — achromatic scatter plot with x-axis labels
/// - `_ExplainerCallout` — contextual card with icon + dynamic messaging
///
/// Presentation-only — takes all state via constructor params.
/// Manages local UI state for bucket selection (tap to explore).
class LeaderboardStatsCard extends StatefulWidget {
  const LeaderboardStatsCard({
    super.key,
    required this.totalPoints,
    required this.totalPointsLabel,
    required this.rank,
    required this.rankLabel,
    required this.distributionCounts,
    required this.userBucketIndex,
    this.minScoreLabel,
    this.userScoreLabel,
    this.maxScoreLabel,
    this.calloutTitle,
    this.calloutBody,
    this.bucketScoreLabels,
    this.onBucketTapped,
  });

  /// The total points value, e.g. "18,000".
  final String totalPoints;

  /// Label above total points, e.g. "TOTAL POINTS".
  final String totalPointsLabel;

  /// The rank value, e.g. "34".
  final String rank;

  /// Label above rank, e.g. "RANK".
  final String rankLabel;

  /// Raw participant counts per bucket.
  final List<int> distributionCounts;

  /// Which column is the user's (highlighted).
  final int userBucketIndex;

  /// X-axis left label, e.g. "0".
  final String? minScoreLabel;

  /// X-axis label under the user column, e.g. "8,000".
  final String? userScoreLabel;

  /// X-axis right label, e.g. "15,000".
  final String? maxScoreLabel;

  /// Callout title, e.g. "Better than 45% of participants".
  final String? calloutTitle;

  /// Callout body with dynamic descriptive text.
  final String? calloutBody;

  /// Pre-formatted score range labels, one per bucket (e.g. "2,000–3,500 pts").
  final List<String>? bucketScoreLabels;

  /// Called when a bucket is tapped or deselected. Null index means deselected.
  final ValueChanged<int?>? onBucketTapped;

  @override
  State<LeaderboardStatsCard> createState() => _LeaderboardStatsCardState();
}

class _LeaderboardStatsCardState extends State<LeaderboardStatsCard> {
  int? _selectedBucketIndex;

  @override
  void didUpdateWidget(LeaderboardStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedBucketIndex != null &&
        _selectedBucketIndex! >= widget.distributionCounts.length) {
      _selectedBucketIndex = null;
    }
  }

  void _onBucketTapped(int index) {
    setState(() {
      _selectedBucketIndex = _selectedBucketIndex == index ? null : index;
    });
    widget.onBucketTapped?.call(_selectedBucketIndex);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final hasSelection = _selectedBucketIndex != null;

    String? effectiveCalloutTitle;
    String? effectiveCalloutBody;

    if (hasSelection) {
      final count = widget.distributionCounts[_selectedBucketIndex!];
      final scoreSpan = (widget.bucketScoreLabels != null &&
              _selectedBucketIndex! < widget.bucketScoreLabels!.length)
          ? widget.bucketScoreLabels![_selectedBucketIndex!]
          : null;
      final isUserBucket = _selectedBucketIndex ==
          widget.userBucketIndex.clamp(0, widget.distributionCounts.length - 1);

      if (isUserBucket && widget.calloutTitle != null) {
        effectiveCalloutTitle = widget.calloutTitle;
        effectiveCalloutBody = scoreSpan != null
            ? '$count participants · $scoreSpan'
            : '$count participants';
      } else {
        effectiveCalloutTitle = '$count participants';
        effectiveCalloutBody = scoreSpan;
      }
    } else {
      effectiveCalloutTitle = widget.calloutTitle;
      effectiveCalloutBody = widget.calloutBody;
    }

    return AppCard(
      color: colors.surfaceContainerLowest,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: widget.totalPointsLabel,
                  value: widget.totalPoints,
                ),
              ),
              SizedBox(width: spacing.space8),
              Expanded(
                child: _StatBox(
                  label: widget.rankLabel,
                  value: widget.rank,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.space16),
          _DotMatrixChart(
            counts: widget.distributionCounts,
            userBucketIndex: widget.userBucketIndex,
            selectedBucketIndex: _selectedBucketIndex,
            onBucketTapped: _onBucketTapped,
            minScoreLabel: widget.minScoreLabel,
            userScoreLabel: widget.userScoreLabel,
            maxScoreLabel: widget.maxScoreLabel,
          ),
          if (effectiveCalloutTitle != null) ...[
            SizedBox(height: spacing.space16),
            _ExplainerCallout(
              title: effectiveCalloutTitle,
              body: effectiveCalloutBody,
              isInteractive: hasSelection,
            ),
          ],
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
    final borders = Theme.of(context).extension<AppBorders>()!;

    return Container(
      padding: EdgeInsets.all(spacing.space24),
      decoration: BoxDecoration(
        borderRadius: radii.borderRadiusLarge,
        border: Border.all(
          color: colors.outlineVariant,
          width: borders.width,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.space4,
        children: [
          Text(
            label.toUpperCase(),
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.start,
          ),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontFamily: kMonoFontFamily,
              color: colors.onSurface,
            ),
            textAlign: TextAlign.start,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DotMatrixChart — achromatic dot-matrix scatter plot with x-axis
// ---------------------------------------------------------------------------

class _DotMatrixChart extends StatefulWidget {
  const _DotMatrixChart({
    required this.counts,
    required this.userBucketIndex,
    this.selectedBucketIndex,
    this.onBucketTapped,
    this.minScoreLabel,
    this.userScoreLabel,
    this.maxScoreLabel,
  });

  final List<int> counts;
  final int userBucketIndex;
  final int? selectedBucketIndex;
  final ValueChanged<int>? onBucketTapped;
  final String? minScoreLabel;
  final String? userScoreLabel;
  final String? maxScoreLabel;

  @override
  State<_DotMatrixChart> createState() => _DotMatrixChartState();
}

class _DotMatrixChartState extends State<_DotMatrixChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _chartHeight = 144.0;
  static const _dotSize = 6.0;
  static const _dotGap = 6.0;
  // Max dots must fit inside the user pill (chart height - 2*pill padding).
  // 11 dots: 11*6 + 10*6 = 126px ≤ 132px (144 - 12).
  static const _maxDots = 11;

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

  static double _columnProgress(int i, int n, double t) {
    final start = i / n;
    final end = (i + 1.5) / n;
    return Curves.easeOutCubic.transform(
      ((t - start) / (end - start)).clamp(0.0, 1.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (widget.counts.isEmpty) return const SizedBox.shrink();

    final clampedIndex =
        widget.userBucketIndex.clamp(0, widget.counts.length - 1);
    final maxCount = widget.counts.reduce(math.max);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot matrix
        SizedBox(
          height: _chartHeight,
          child: reduceMotion
              ? _buildColumns(
                  colors: colors,
                  radii: radii,
                  spacing: spacing,
                  clampedIndex: clampedIndex,
                  maxCount: maxCount,
                  animationValue: 1.0,
                )
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _buildColumns(
                    colors: colors,
                    radii: radii,
                    spacing: spacing,
                    clampedIndex: clampedIndex,
                    maxCount: maxCount,
                    animationValue: _controller.value,
                  ),
                ),
        ),

        // X-axis labels
        if (widget.minScoreLabel != null || widget.maxScoreLabel != null)
          Padding(
            padding: EdgeInsets.only(top: spacing.space4),
            child: _buildXAxis(
              colors: colors,
              textTheme: textTheme,
              clampedIndex: clampedIndex,
            ),
          ),
      ],
    );
  }

  Widget _buildColumns({
    required ColorScheme colors,
    required AppRadii radii,
    required AppSpacing spacing,
    required int clampedIndex,
    required int maxCount,
    required double animationValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < widget.counts.length; i++)
          Expanded(
            child: _buildColumn(
              index: i,
              count: widget.counts[i],
              maxCount: maxCount,
              clampedIndex: clampedIndex,
              colors: colors,
              radii: radii,
              spacing: spacing,
              animationValue: animationValue,
            ),
          ),
      ],
    );
  }

  Widget _buildColumn({
    required int index,
    required int count,
    required int maxCount,
    required int clampedIndex,
    required ColorScheme colors,
    required AppRadii radii,
    required AppSpacing spacing,
    required double animationValue,
  }) {
    final isUser = index == clampedIndex;
    final isBefore = index < clampedIndex;
    final hasAnySelection = widget.selectedBucketIndex != null;
    final isSelected = widget.selectedBucketIndex == index;

    // Scale counts to max dots
    int dotCount;
    if (maxCount == 0 || count == 0) {
      dotCount = 0;
    } else {
      dotCount = (count / maxCount * _maxDots).ceil().clamp(1, _maxDots);
    }

    // Animation
    final progress = animationValue >= 1.0
        ? 1.0
        : _columnProgress(index, widget.counts.length, animationValue);
    final visibleDots = (dotCount * progress).ceil();

    // Dot color with selection awareness
    Color dotColor;
    if (isSelected) {
      dotColor = colors.onSurface;
    } else if (isUser && !hasAnySelection) {
      dotColor = colors.onSurface;
    } else if (isUser && hasAnySelection) {
      dotColor = colors.outline;
    } else if (isBefore) {
      dotColor = colors.outlineVariant;
    } else {
      dotColor = colors.surfaceContainerHighest;
    }

    final dots = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var d = 0; d < visibleDots; d++)
          Padding(
            padding: EdgeInsets.only(top: d == 0 ? 0 : _dotGap),
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    // Show pill on selected bucket, or user bucket when nothing is selected
    final showPill = isSelected || (isUser && !hasAnySelection);

    Widget column;
    if (showPill) {
      column = Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.all(spacing.space8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: radii.borderRadiusFull,
          ),
          child: dots,
        ),
      );
    } else {
      column = Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(bottom: spacing.space8),
          child: dots,
        ),
      );
    }

    // Wrap in GestureDetector for tappable buckets (only if count > 0)
    if (count > 0 && widget.onBucketTapped != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onBucketTapped!(index),
        child: column,
      );
    }

    return column;
  }

  Widget _buildXAxis({
    required ColorScheme colors,
    required TextTheme textTheme,
    required int clampedIndex,
  }) {
    final labelStyle = textTheme.labelSmall?.copyWith(
      fontFamily: kMonoFontFamily,
      color: colors.onSurfaceVariant,
    );
    final userLabelStyle = textTheme.labelSmall?.copyWith(
      fontFamily: kMonoFontFamily,
      color: colors.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (widget.minScoreLabel != null)
              Text(widget.minScoreLabel!, style: labelStyle)
            else
              const SizedBox.shrink(),
            if (widget.maxScoreLabel != null)
              Text(widget.maxScoreLabel!, style: labelStyle)
            else
              const SizedBox.shrink(),
          ],
        ),
        if (widget.userScoreLabel != null)
          Align(
            alignment: Alignment(
              -1.0 +
                  2.0 * clampedIndex / (widget.counts.length - 1).clamp(1, 999),
              0,
            ),
            child: Text(widget.userScoreLabel!, style: userLabelStyle),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ExplainerCallout — contextual card with icon + dynamic messaging
// ---------------------------------------------------------------------------

class _ExplainerCallout extends StatelessWidget {
  const _ExplainerCallout({
    required this.title,
    this.body,
    this.isInteractive = false,
  });

  final String title;
  final String? body;
  final bool isInteractive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(spacing.space16),
      decoration: BoxDecoration(
        color: isInteractive
            ? colors.surfaceContainerHigh
            : colors.surfaceContainerLow,
        borderRadius: radii.borderRadiusLarge,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.space16,
        children: [
          Icon(
            Symbols.bar_chart_4_bars,
            size: sizing.iconSmall,
            color: colors.onSurfaceVariant,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                if (body != null) ...[
                  SizedBox(height: spacing.space4),
                  Text(
                    body!,
                    style: textTheme.bodySmall?.copyWith(
                      color:
                          colors.onSurface.withValues(alpha: opacity.secondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
