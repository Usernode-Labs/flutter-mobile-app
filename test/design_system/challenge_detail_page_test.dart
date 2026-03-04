import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  ChallengeRewardCard buildRewardCard() {
    return const ChallengeRewardCard(
      category: ChallengeCategory.technical,
      totalEarned: '10,550.1',
      data: ProduceBlocksRewardData(
        progressFraction: 0.98,
        successRate: '98%',
        maxPoints: '5,000',
        totalPoints: '4,900',
        rankReward: '+0',
      ),
      epochEarned: '+50',
      epochLabel: 'View Epoch 176',
    );
  }

  group('ChallengeDetailPage', () {
    testWidgets('renders title in TopAppBar', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
        ),
      ));

      // Title appears in both collapsed and expanded states of TopAppBar.
      expect(find.text('Produce Every Block'), findsWidgets);
    });

    testWidgets('renders subtitle in TopAppBar', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
        ),
      ));

      expect(find.text('Technical · Jan 12 - Jan 30'), findsOneWidget);
    });

    testWidgets('renders all description sections', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Why explanation.'),
            (title: 'Task', body: 'Task description.'),
            (title: 'Requirements', body: 'Requirements list.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
        ),
      ));

      expect(find.text('The Why'), findsOneWidget);
      expect(find.text('Why explanation.'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Task description.'), findsOneWidget);
      expect(find.text('Requirements'), findsOneWidget);
      expect(find.text('Requirements list.'), findsOneWidget);
    });

    testWidgets('renders total reward card', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
        ),
      ));

      expect(find.text('Total Reward Up to 6,500 pts'), findsOneWidget);
      expect(find.text('Base reward details.'), findsOneWidget);
    });

    testWidgets('onBackTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
          onBackTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
      expect(tapped, isTrue);
    });

    testWidgets('renders reward card widget', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Produce Every Block',
          category: ChallengeCategory.technical,
          dateRange: 'Technical · Jan 12 - Jan 30',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 6,500 pts',
          totalRewardBody: 'Base reward details.',
        ),
      ));

      expect(find.byType(ChallengeRewardCard), findsOneWidget);
    });

    testWidgets('hides reward card when rewardCard is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeDetailPage(
          title: 'Community Post',
          category: ChallengeCategory.community,
          dateRange: 'Community · Feb 1 - Feb 28',
          rewardCard: null,
          sections: [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 2,000 pts',
          totalRewardBody: 'Community reward details.',
        ),
      ));

      expect(find.byType(ChallengeRewardCard), findsNothing);
      // Sections and total reward card still render
      expect(find.text('The Why'), findsOneWidget);
      expect(find.text('Total Reward Up to 2,000 pts'), findsOneWidget);
    });

    testWidgets('renders ChallengeCategoryIcon in app bar', (tester) async {
      await tester.pumpWidget(wrap(
        ChallengeDetailPage(
          title: 'Community Post',
          category: ChallengeCategory.community,
          dateRange: 'Community · Feb 1 - Feb 28',
          rewardCard: buildRewardCard(),
          sections: const [
            (title: 'The Why', body: 'Some explanation.'),
          ],
          totalRewardHeading: 'Total Reward Up to 2,000 pts',
          totalRewardBody: 'Community reward details.',
        ),
      ));

      expect(find.byType(ChallengeCategoryIcon), findsOneWidget);
    });
  });
}
