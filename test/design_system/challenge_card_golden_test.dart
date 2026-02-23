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

  group('ChallengeCard golden', () {
    testWidgets('active variant', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Run a Full Node',
          description:
              'Keep your node running and connected for the entire challenge period to earn maximum rewards.',
          dateRange: 'Jan 15 - Feb 15',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          rewardText: 'Up to 1000 pts',
        ),
      ));

      await expectLater(
        find.byType(ChallengeCard),
        matchesGoldenFile('goldens/challenge_card_active.png'),
      );
    });

    testWidgets('ongoing variant', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Run a Full Node',
          description:
              'Keep your node running and connected for the entire challenge period.',
          dateRange: 'Jan 15 - Feb 15',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          variant: ChallengeCardVariant.ongoing,
          earnedPoints: '10,550.1 pts',
          epochPoints: '+50 pts',
        ),
      ));

      // Pump one frame so animation controller ticks
      await tester.pump(const Duration(milliseconds: 100));

      await expectLater(
        find.byType(ChallengeCard),
        matchesGoldenFile('goldens/challenge_card_ongoing.png'),
      );
    });

    testWidgets('completed variant', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Community Engagement',
          description: 'Share your node stats on social media.',
          dateRange: 'Feb 1 - Feb 28',
          category: ChallengeCategory.community,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.community),
          variant: ChallengeCardVariant.completed,
          completedPoints: '500 pts',
        ),
      ));

      await expectLater(
        find.byType(ChallengeCard),
        matchesGoldenFile('goldens/challenge_card_completed.png'),
      );
    });

    testWidgets('missed variant', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Flash: Speed Run',
          description: 'Complete 5 transactions within 1 hour.',
          dateRange: 'Feb 10 - Feb 10',
          category: ChallengeCategory.flash,
          categoryIcon:
              const ChallengeCategoryIcon(category: ChallengeCategory.flash),
          variant: ChallengeCardVariant.missed,
          completedPoints: '200 pts',
        ),
      ));

      await expectLater(
        find.byType(ChallengeCard),
        matchesGoldenFile('goldens/challenge_card_missed.png'),
      );
    });
  });
}
