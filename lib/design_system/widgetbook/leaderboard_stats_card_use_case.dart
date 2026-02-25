import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/leaderboard_stats_card.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent leaderboardStatsCardComponent() {
  return WidgetbookComponent(
    name: 'LeaderboardStatsCard',
    useCases: [
      _playground(),
      _variants(),
      _edgeCases(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Use case 1 — Playground
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      final totalPoints = context.knobs.string(
        label: 'Total Points',
        initialValue: '18,000',
      );

      final rank = context.knobs.string(
        label: 'Rank',
        initialValue: '34',
      );

      final userBarIndex = context.knobs.double
          .slider(
            label: 'User Bar Index',
            initialValue: 6,
            min: 0,
            max: 15,
          )
          .round();

      final showTooltip = context.knobs.boolean(
        label: 'Show Tooltip',
        initialValue: true,
      );

      final tooltipText = context.knobs.string(
        label: 'Tooltip Text',
        initialValue: 'Better than 45% of participants.',
      );

      final distribution = _bellCurve(16);

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: LeaderboardStatsCard(
          totalPoints: totalPoints,
          totalPointsLabel: 'TOTAL POINTS',
          rank: rank,
          rankLabel: 'RANK',
          distribution: distribution,
          userBarIndex: userBarIndex,
          tooltipText: showTooltip ? tooltipText : null,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — Variants
// ---------------------------------------------------------------------------

WidgetbookUseCase _variants() {
  return WidgetbookUseCase(
    name: 'Distribution Shapes',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BELL CURVE',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '18,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '34',
              rankLabel: 'RANK',
              distribution: _bellCurve(16),
              userBarIndex: 6,
              tooltipText: 'Better than 45% of participants.',
            ),
            SizedBox(height: spacing.space24),
            Text(
              'LEFT SKEWED',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '5,200',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '128',
              rankLabel: 'RANK',
              distribution: _leftSkewed(16),
              userBarIndex: 3,
              tooltipText: 'Better than 20% of participants.',
            ),
            SizedBox(height: spacing.space24),
            Text(
              'FLAT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '10,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '50',
              rankLabel: 'RANK',
              distribution: _flat(16),
              userBarIndex: 8,
            ),
            SizedBox(height: spacing.space24),
            Text(
              'WITHOUT TOOLTIP',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '22,500',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '7',
              rankLabel: 'RANK',
              distribution: _bellCurve(16),
              userBarIndex: 12,
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 3 — Edge Cases
// ---------------------------------------------------------------------------

WidgetbookUseCase _edgeCases() {
  return WidgetbookUseCase(
    name: 'Edge Cases',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return SingleChildScrollView(
        padding: EdgeInsets.all(spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'USER AT FIRST (ALL GREY — NO EARNED TERRITORY)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '500',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '200',
              rankLabel: 'RANK',
              distribution: _bellCurve(16),
              userBarIndex: 0,
              tooltipText: 'Better than 0% of participants.',
            ),
            SizedBox(height: spacing.space24),
            Text(
              'USER AT LAST (ALL GREEN — FULLY CONQUERED)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '99,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '1',
              rankLabel: 'RANK',
              distribution: _bellCurve(16),
              userBarIndex: 15,
              tooltipText: 'Better than 99% of participants.',
            ),
            SizedBox(height: spacing.space24),
            Text(
              'WIDE BARS (4 BARS)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '12,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '15',
              rankLabel: 'RANK',
              distribution: _bellCurve(4),
              userBarIndex: 2,
              tooltipText: 'Better than 60% of participants.',
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Distribution generators
// ---------------------------------------------------------------------------

List<double> _bellCurve(int count) {
  final center = count / 2;
  final sigma = count / 4;
  return List.generate(count, (i) {
    final x = (i - center) / sigma;
    return math.exp(-0.5 * x * x);
  });
}

List<double> _leftSkewed(int count) {
  return List.generate(count, (i) {
    final t = i / (count - 1);
    return math.pow(1 - t, 2.5).toDouble();
  });
}

List<double> _flat(int count) {
  return List.generate(count, (_) => 0.4 + 0.2 * math.Random(42).nextDouble());
}
