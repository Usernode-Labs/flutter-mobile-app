import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

      final bucketCount = context.knobs.double
          .slider(
            label: 'Bucket Count',
            initialValue: 16,
            min: 6,
            max: 20,
          )
          .round();

      final totalPoints = context.knobs.string(
        label: 'Total Points',
        initialValue: '18,000',
      );

      final rank = context.knobs.string(
        label: 'Rank',
        initialValue: '34',
      );

      final userBucketIndex = context.knobs.double
          .slider(
            label: 'User Bucket Index',
            initialValue: 6,
            min: 0,
            max: 19,
          )
          .round()
          .clamp(0, bucketCount - 1);

      final showCallout = context.knobs.boolean(
        label: 'Show Callout',
        initialValue: true,
      );

      final calloutTitle = context.knobs.string(
        label: 'Callout Title',
        initialValue: 'Better than 45% of participants',
      );

      final calloutBody = context.knobs.string(
        label: 'Callout Body',
        initialValue:
            "You're in the top 55%! Keep completing challenges to secure your position.",
      );

      final minScore = context.knobs.string(
        label: 'Min Score Label',
        initialValue: '0',
      );

      final userScore = context.knobs.string(
        label: 'User Score Label',
        initialValue: '8,000',
      );

      final maxScore = context.knobs.string(
        label: 'Max Score Label',
        initialValue: '15,000',
      );

      final distribution = _bellCurveCounts(bucketCount);
      final scoreLabels = _mockScoreLabels(bucketCount, 0, 15000);

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: LeaderboardStatsCard(
          totalPoints: totalPoints,
          totalPointsLabel: 'TOTAL POINTS',
          rank: rank,
          rankLabel: 'RANK',
          distributionCounts: distribution,
          userBucketIndex: userBucketIndex,
          minScoreLabel: minScore,
          userScoreLabel: userScore,
          maxScoreLabel: maxScore,
          calloutTitle: showCallout ? calloutTitle : null,
          calloutBody: showCallout ? calloutBody : null,
          bucketScoreLabels: scoreLabels,
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
              'BELL CURVE (16 BUCKETS)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '18,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '34',
              rankLabel: 'RANK',
              distributionCounts: _bellCurveCounts(16),
              userBucketIndex: 6,
              minScoreLabel: '0',
              userScoreLabel: '8,000',
              maxScoreLabel: '15,000',
              calloutTitle: 'Better than 45% of participants',
              calloutBody:
                  "You're in the top 55%! Keep completing challenges to secure your position.",
              bucketScoreLabels: _mockScoreLabels(16, 0, 15000),
            ),
            SizedBox(height: spacing.space24),
            Text(
              'LEFT SKEWED (10 BUCKETS)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '5,200',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '128',
              rankLabel: 'RANK',
              distributionCounts: _leftSkewedCounts(10),
              userBucketIndex: 3,
              minScoreLabel: '0',
              userScoreLabel: '2,500',
              maxScoreLabel: '12,000',
              calloutTitle: 'Better than 20% of participants',
              calloutBody:
                  'Keep completing tasks to climb higher on the leaderboard.',
              bucketScoreLabels: _mockScoreLabels(10, 0, 12000),
            ),
            SizedBox(height: spacing.space24),
            Text(
              'FLAT (8 BUCKETS)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '10,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '50',
              rankLabel: 'RANK',
              distributionCounts: _flatCounts(8),
              userBucketIndex: 4,
              minScoreLabel: '0',
              userScoreLabel: '10,000',
              maxScoreLabel: '20,000',
              bucketScoreLabels: _mockScoreLabels(8, 0, 20000),
            ),
            SizedBox(height: spacing.space24),
            Text(
              'WITHOUT CALLOUT',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '22,500',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '7',
              rankLabel: 'RANK',
              distributionCounts: _bellCurveCounts(16),
              userBucketIndex: 12,
              minScoreLabel: '0',
              maxScoreLabel: '25,000',
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
              'USER AT FIRST (BOTTOM HALF — ENCOURAGING)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '500',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '200',
              rankLabel: 'RANK',
              distributionCounts: _bellCurveCounts(16),
              userBucketIndex: 0,
              minScoreLabel: '0',
              userScoreLabel: '500',
              maxScoreLabel: '15,000',
              calloutTitle: 'Better than 0% of participants',
              calloutBody:
                  'Keep completing tasks to climb higher on the leaderboard.',
              bucketScoreLabels: _mockScoreLabels(16, 0, 15000),
            ),
            SizedBox(height: spacing.space24),
            Text(
              'USER AT LAST (TOP — ACCOMPLISHED)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '99,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '1',
              rankLabel: 'RANK',
              distributionCounts: _bellCurveCounts(16),
              userBucketIndex: 15,
              minScoreLabel: '0',
              userScoreLabel: '99,000',
              maxScoreLabel: '100,000',
              calloutTitle: 'Better than 99% of participants',
              calloutBody:
                  "You're in the top 1%! Keep completing challenges to secure your position.",
              bucketScoreLabels: _mockScoreLabels(16, 0, 100000),
            ),
            SizedBox(height: spacing.space24),
            Text(
              'WIDE COLUMNS (4 BUCKETS)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            SizedBox(height: spacing.space8),
            LeaderboardStatsCard(
              totalPoints: '12,000',
              totalPointsLabel: 'TOTAL POINTS',
              rank: '15',
              rankLabel: 'RANK',
              distributionCounts: _bellCurveCounts(4),
              userBucketIndex: 2,
              minScoreLabel: '0',
              userScoreLabel: '12,000',
              maxScoreLabel: '20,000',
              calloutTitle: 'Better than 60% of participants',
              bucketScoreLabels: _mockScoreLabels(4, 0, 20000),
            ),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Distribution generators — return raw counts
// ---------------------------------------------------------------------------

List<int> _bellCurveCounts(int count) {
  final center = count / 2;
  final sigma = count / 4;
  return List.generate(count, (i) {
    final x = (i - center) / sigma;
    return (math.exp(-0.5 * x * x) * 45).round().clamp(1, 50);
  });
}

List<int> _leftSkewedCounts(int count) {
  return List.generate(count, (i) {
    final t = i / (count - 1);
    return (math.pow(1 - t, 2.5) * 40).round().clamp(0, 50);
  });
}

List<int> _flatCounts(int count) {
  final rng = math.Random(42);
  return List.generate(count, (_) => 8 + (rng.nextDouble() * 10).round());
}

List<String> _mockScoreLabels(int bucketCount, int minPts, int maxPts) {
  final fmt = NumberFormat('#,##0');
  final bucketWidth = (maxPts - minPts) / bucketCount;
  return List.generate(bucketCount, (i) {
    final lo = (minPts + i * bucketWidth).round();
    final hi = i == bucketCount - 1
        ? maxPts
        : (minPts + (i + 1) * bucketWidth).round();
    return '${fmt.format(lo)}–${fmt.format(hi)} pts';
  });
}
