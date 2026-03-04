import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
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

  group('ChallengeCard', () {
    testWidgets('renders active variant', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Run a Node',
          description: 'Keep your node running for 24 hours',
          dateRange: 'Jan 1 - Jan 31',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          rewardText: 'Up to 1000 pts',
        ),
      ));

      expect(find.text('Run a Node'), findsOneWidget);
      expect(find.text('Keep your node running for 24 hours'), findsOneWidget);
      expect(find.text('JAN 1 - JAN 31'), findsOneWidget);
      expect(find.text('TECHNICAL'), findsOneWidget);
      expect(find.text('Up to 1000 pts'), findsOneWidget);
    });

    testWidgets('renders ongoing variant with category color bar',
        (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Run a Node',
          description: 'Keep your node running for 24 hours',
          dateRange: 'Jan 1 - Jan 31',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          variant: ChallengeCardVariant.ongoing,
          earnedPoints: '10,550.1 pts',
          epochPoints: '+50 pts',
        ),
      ));

      expect(find.text('Earned 10,550.1 pts'), findsOneWidget);
      expect(find.text('Current Epoch +50 pts'), findsOneWidget);
    });

    testWidgets('renders completed variant with checkmark', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Community Post',
          description: 'Share your progress on social media',
          dateRange: 'Feb 1 - Feb 28',
          category: ChallengeCategory.community,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.community),
          variant: ChallengeCardVariant.completed,
          completedPoints: '500 pts',
        ),
      ));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('500 pts'), findsOneWidget);
      expect(find.byIcon(Symbols.check_circle_sharp), findsOneWidget);
    });

    testWidgets('renders missed variant with event_busy icon', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Flash Challenge',
          description: 'Complete 5 transactions in 1 hour',
          dateRange: 'Feb 10 - Feb 10',
          category: ChallengeCategory.flash,
          categoryIcon:
              const ChallengeCategoryIcon(category: ChallengeCategory.flash),
          variant: ChallengeCardVariant.missed,
          completedPoints: '200 pts',
        ),
      ));

      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('200 pts'), findsOneWidget);
      expect(find.byIcon(Symbols.event_busy_sharp), findsOneWidget);
    });

    testWidgets('onTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ChallengeCard(
          title: 'Tap Me',
          description: 'Test tap',
          dateRange: 'Jan 1 - Jan 31',
          category: ChallengeCategory.technical,
          categoryIcon: const ChallengeCategoryIcon(
              category: ChallengeCategory.technical),
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });
  });
}
