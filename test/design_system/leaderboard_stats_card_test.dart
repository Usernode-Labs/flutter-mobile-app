import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThemeData themeWithExtensions() {
    final cieTheme = ColorIsExpensiveTheme(ThemeData.light().textTheme);
    return cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );
  }

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    );
  }

  final sampleDistribution = [
    0.1, 0.2, 0.35, 0.5, 0.7, 0.85, 1.0, 0.9, 0.75, 0.6, //
    0.45, 0.3, 0.2, 0.15, 0.1, 0.05,
  ];

  group('LeaderboardStatsCard', () {
    testWidgets('renders total points label and value', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distribution: sampleDistribution,
          userBarIndex: 6,
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
          distribution: sampleDistribution,
          userBarIndex: 6,
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
          distribution: sampleDistribution,
          userBarIndex: 6,
          tooltipText: 'Better than 45% of participants.',
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
          distribution: sampleDistribution,
          userBarIndex: 6,
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
          distribution: [],
          userBarIndex: 0,
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
          distribution: sampleDistribution,
          userBarIndex: 6,
          tooltipText: 'Better than 45% of participants.',
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
          distribution: sampleDistribution,
          userBarIndex: 6,
        ),
      ));

      expect(find.text('TOTAL POINTS'), findsOneWidget);
      expect(find.text('RANK'), findsOneWidget);
    });

    testWidgets('tooltip uses community color', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distribution: sampleDistribution,
          userBarIndex: 6,
          tooltipText: 'Better than 45% of participants.',
        ),
      ));
      await tester.pumpAndSettle();

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;

      final tooltipText = find.text('Better than 45% of participants.');
      final container = find.ancestor(
        of: tooltipText,
        matching: find.byType(Container),
      );

      // The closest Container ancestor with a decoration is the tooltip bg.
      final containerWidget =
          tester.widgetList<Container>(container).firstWhere(
                (c) => c.decoration is BoxDecoration,
              );
      final decoration = containerWidget.decoration! as BoxDecoration;
      expect(decoration.color, semantic.community.color);
    });

    testWidgets('user bar has BoxShadow', (tester) async {
      await tester.pumpWidget(wrap(
        LeaderboardStatsCard(
          totalPoints: '18,000',
          totalPointsLabel: 'TOTAL POINTS',
          rank: '34',
          rankLabel: 'RANK',
          distribution: sampleDistribution,
          userBarIndex: 6,
        ),
      ));
      await tester.pumpAndSettle();

      final theme = themeWithExtensions();
      final semantic = theme.extension<AppSemanticColors>()!;

      // Find all bar Containers inside the chart.
      final allContainers = find.byType(Container);
      var foundShadow = false;
      for (final element in tester.widgetList<Container>(allContainers)) {
        final decoration = element.decoration;
        if (decoration is BoxDecoration &&
            decoration.color == semantic.community.color &&
            decoration.boxShadow != null &&
            decoration.boxShadow!.isNotEmpty) {
          foundShadow = true;
          expect(decoration.boxShadow!.first.blurRadius, 6.0);
          break;
        }
      }
      expect(foundShadow, isTrue, reason: 'User bar should have a BoxShadow');
    });
  });
}
