import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 500, child: child),
        ),
      ),
    );
  }

  final sampleDistribution = [
    1, 2, 4, 5, 7, 9, 10, 9, 8, 6, //
    5, 3, 2, 2, 1, 1,
  ];

  group('LeaderboardStatsCard', () {
    testWidgets('renders total points label and value', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));

      expect(find.text('TOTAL POINTS'), findsOneWidget);
      expect(find.text('18,000'), findsOneWidget);
    });

    testWidgets('renders rank label and value', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));

      expect(find.text('RANK'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
    });

    testWidgets('renders tooltip text when provided', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45% of participants.',
        ),
      ));

      expect(find.text('Better than 45% of participants.'), findsOneWidget);
    });

    testWidgets('hides tooltip when null', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));

      expect(find.text('Better than 45% of participants.'), findsNothing);
    });

    testWidgets('renders without error with empty distribution',
        (tester) async {
      await tester.pumpWidget(wrap(
        const LeaderboardStatsCard(
          totalPoints: '0',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '-',
          rankLabel: 'RANK',
          distributionCounts: [],
          userBucketIndex: 0,
        ),
      ));

      expect(find.byType(LeaderboardStatsCard), findsOneWidget);
    });

    testWidgets('renders with all options', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45% of participants.',
        ),
      ));

      expect(find.byType(LeaderboardStatsCard), findsOneWidget);
    });

    testWidgets('stat box labels are uppercased', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'total points',
          rank: '34',
          rankLabel: 'rank',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));

      expect(find.text('TOTAL POINTS'), findsOneWidget);
      expect(find.text('RANK'), findsOneWidget);
    });

    testWidgets('callout has surfaceContainerLow background', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45% of participants.',
        ),
      ));
      await tester.pumpAndSettle();

      final theme = themeWithExtensions();
      final expectedColor = theme.colorScheme.surfaceContainerLow;

      final calloutText = find.text('Better than 45% of participants.');
      final container = find.ancestor(
        of: calloutText,
        matching: find.byType(Container),
      );

      final containerWidget =
          tester.widgetList<Container>(container).firstWhere(
                (c) => c.decoration is BoxDecoration,
              );
      final decoration = containerWidget.decoration! as BoxDecoration;
      expect(decoration.color, expectedColor);
    });

    testWidgets('user column has highlighted pill background', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));
      await tester.pumpAndSettle();

      final theme = themeWithExtensions();
      final expectedColor = theme.colorScheme.surfaceContainerHigh;

      // Find the highlighted pill Container wrapping the user's dot column.
      final allContainers = find.byType(Container);
      var foundPill = false;
      for (final element in tester.widgetList<Container>(allContainers)) {
        final decoration = element.decoration;
        if (decoration is BoxDecoration &&
            decoration.color == expectedColor &&
            decoration.borderRadius != null) {
          foundPill = true;
          break;
        }
      }
      expect(foundPill, isTrue,
          reason: 'User column should have a highlighted pill background');
    });

    testWidgets('tapping a chart column shows bucket count in callout',
        (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45%',
        ),
      ));
      await tester.pumpAndSettle();

      // Find the chart area (SizedBox with chart height 144)
      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      // Tap column 2 (count = 4)
      await tester.tapAt(Offset(
        chartTopLeft.dx + columnWidth * 2 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('4 participants'), findsOneWidget);
      expect(find.text('Better than 45%'), findsNothing);
    });

    testWidgets('tapping selected bucket again restores default callout',
        (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45%',
        ),
      ));
      await tester.pumpAndSettle();

      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      final tapOffset = Offset(
        chartTopLeft.dx + columnWidth * 2 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      );

      // Tap to select
      await tester.tapAt(tapOffset);
      await tester.pumpAndSettle();
      expect(find.text('4 participants'), findsOneWidget);

      // Tap again to deselect
      await tester.tapAt(tapOffset);
      await tester.pumpAndSettle();
      expect(find.text('Better than 45%'), findsOneWidget);
      expect(find.text('4 participants'), findsNothing);
    });

    testWidgets('onBucketTapped callback fires with correct index',
        (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          onBucketTapped: (index) => tappedIndex = index,
        ),
      ));
      await tester.pumpAndSettle();

      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      // Tap column 2
      await tester.tapAt(Offset(
        chartTopLeft.dx + columnWidth * 2 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      ));
      await tester.pumpAndSettle();

      expect(tappedIndex, 2);
    });

    testWidgets('tapping bucket without default callout shows callout',
        (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
        ),
      ));
      await tester.pumpAndSettle();

      // No callout initially
      expect(find.text('4 participants'), findsNothing);

      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      // Tap column 2 (count = 4)
      await tester.tapAt(Offset(
        chartTopLeft.dx + columnWidth * 2 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      ));
      await tester.pumpAndSettle();

      // Callout should now appear
      expect(find.text('4 participants'), findsOneWidget);
    });

    testWidgets(
        'tapping non-user bucket with score labels shows count and score span',
        (tester) async {
      final scoreLabels = List.generate(
        sampleDistribution.length,
        (i) => '${i * 100}–${(i + 1) * 100} pts',
      );

      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45%',
          bucketScoreLabels: scoreLabels,
        ),
      ));
      await tester.pumpAndSettle();

      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      // Tap column 2 (count = 4, non-user bucket)
      await tester.tapAt(Offset(
        chartTopLeft.dx + columnWidth * 2 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      ));
      await tester.pumpAndSettle();

      expect(find.text('4 participants'), findsOneWidget);
      expect(find.text('200–300 pts'), findsOneWidget);
    });

    testWidgets(
        'tapping user bucket shows original callout title with count and score span',
        (tester) async {
      final scoreLabels = List.generate(
        sampleDistribution.length,
        (i) => '${i * 100}–${(i + 1) * 100} pts',
      );

      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distributionCounts: sampleDistribution,
          userBucketIndex: 6,
          calloutTitle: 'Better than 45%',
          bucketScoreLabels: scoreLabels,
        ),
      ));
      await tester.pumpAndSettle();

      final chartArea = find.byWidgetPredicate(
        (w) => w is SizedBox && w.height == 144.0,
      );
      final chartTopLeft = tester.getTopLeft(chartArea);
      final chartSize = tester.getSize(chartArea);
      final columnWidth = chartSize.width / sampleDistribution.length;

      // Tap the user's bucket (index 6, count = 10)
      await tester.tapAt(Offset(
        chartTopLeft.dx + columnWidth * 6 + columnWidth / 2,
        chartTopLeft.dy + chartSize.height / 2,
      ));
      await tester.pumpAndSettle();

      // Original callout title preserved
      expect(find.text('Better than 45%'), findsOneWidget);
      // Body shows count + score span
      expect(find.text('10 participants · 600–700 pts'), findsOneWidget);
    });
  });
}
