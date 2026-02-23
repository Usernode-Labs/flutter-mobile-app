@Tags(['golden'])
library;

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

  group('ScoreHeader golden', () {
    testWidgets('standard variant', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          rankLabel: 'Rank 44',
          progress: 0.75,
          countdownTime: '12 DAYS 5H 3M',
          ctaLabel: 'View in Leaderboard',
        ),
      ));

      await expectLater(
        find.byType(ScoreHeader),
        matchesGoldenFile('goldens/score_header_standard.png'),
      );
    });

    testWidgets('glow variant', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          rankLabel: 'Rank 44',
          progress: 0.75,
          countdownTime: '12 DAYS 5H 3M',
          ctaLabel: 'View in Leaderboard',
          variant: ScoreHeaderVariant.glow,
        ),
      ));

      await expectLater(
        find.byType(ScoreHeader),
        matchesGoldenFile('goldens/score_header_glow.png'),
      );
    });

    testWidgets('minimal (no optional elements)', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '0',
          scoreLabel: 'points',
        ),
      ));

      await expectLater(
        find.byType(ScoreHeader),
        matchesGoldenFile('goldens/score_header_minimal.png'),
      );
    });
  });
}
