import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );
  }

  const produceBlocksData = ProduceBlocksRewardData(
    progressFraction: 0.98,
    successRate: '98%',
    maxPoints: '5,000',
    totalPoints: '4,900',
    rankReward: '+0',
  );

  group('ChallengeRewardCard – ProduceBlocksRewardData', () {
    testWidgets('renders total earned and points label', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
        ),
      ));

      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('10,550.1'), findsOneWidget);
      expect(find.text('pts'), findsOneWidget);
    });

    testWidgets('renders calculation row', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
        ),
      ));

      expect(find.text('SUCCESS RATE'), findsOneWidget);
      expect(find.text('98%'), findsOneWidget);
      expect(find.text('MAX PTS'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);
      expect(find.text('TOTAL'), findsOneWidget);
      expect(find.text('4,900'), findsOneWidget);
    });

    testWidgets('renders rank reward row', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.community,
          totalEarned: '500',
          data: ProduceBlocksRewardData(
            progressFraction: 0.5,
            successRate: '50%',
            maxPoints: '1,000',
            totalPoints: '500',
            rankReward: '+100',
          ),
        ),
      ));

      expect(find.text('TOP 3 RANK REWARD'), findsOneWidget);
      expect(find.text('+100'), findsOneWidget);
    });

    testWidgets('hides epoch section when epochEarned is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
        ),
      ));

      expect(find.text('This Epoch Earned'), findsNothing);
    });

    testWidgets('shows epoch section when epochEarned is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
          epochEarned: '+50',
          epochLabel: 'View Epoch 176',
        ),
      ));

      expect(find.text('This Epoch Earned'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(find.text('View Epoch 176'), findsOneWidget);
    });

    testWidgets('uses custom epochSectionLabel when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
          epochSectionLabel: 'Last 24h',
          epochEarned: '+50',
        ),
      ));

      expect(find.text('Last 24h'), findsOneWidget);
      expect(find.text('This Epoch Earned'), findsNothing);
    });

    testWidgets('epoch button fires onEpochTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          data: produceBlocksData,
          epochEarned: '+50',
          epochLabel: 'View Epoch 176',
          onEpochTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('View Epoch 176'));
      expect(tapped, isTrue);
    });

    testWidgets('uses category color for background', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '100',
          data: ProduceBlocksRewardData(
            progressFraction: 1.0,
            successRate: '100%',
            maxPoints: '100',
            totalPoints: '100',
            rankReward: '+0',
          ),
        ),
      ));

      // Find the outermost Container (the card background)
      final semantic = AppSemanticColors.light();
      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, equals(semantic.technical.color));
    });

    testWidgets('renders rank label pill when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '6,491',
          data: ProduceBlocksRewardData(
            progressFraction: 0.98,
            successRate: '98%',
            maxPoints: '5,000',
            totalPoints: '4,900',
            rankLabel: '1st',
            rankReward: '+500',
          ),
        ),
      ));

      expect(find.text('1st'), findsOneWidget);
      expect(find.text('TOP 3 RANK REWARD'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
    });

    testWidgets('hides rank label pill when rankLabel is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '6,491',
          data: produceBlocksData,
        ),
      ));

      expect(find.text('1st'), findsNothing);
      expect(find.text('2nd'), findsNothing);
      expect(find.text('3rd'), findsNothing);
    });
  });

  group('ChallengeRewardCard – SimpleRewardData', () {
    testWidgets('renders "Total Earned" label and points, no calculation row',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.community,
          totalEarned: '500',
          data: SimpleRewardData(),
        ),
      ));

      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('pts'), findsOneWidget);

      // No produce-blocks elements
      expect(find.text('SUCCESS RATE'), findsNothing);
      expect(find.text('MAX PTS'), findsNothing);
      expect(find.text('TOTAL'), findsNothing);
      expect(find.text('TOP 3 RANK REWARD'), findsNothing);
    });

    testWidgets('shows epoch section when epochEarned is provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.flash,
          totalEarned: '200',
          data: SimpleRewardData(),
          epochSectionLabel: 'Last 24h',
          epochEarned: '+25',
        ),
      ));

      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('Last 24h'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
    });

    testWidgets('hides epoch section when epochEarned is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.community,
          totalEarned: '500',
          data: SimpleRewardData(),
        ),
      ));

      expect(find.text('This Epoch Earned'), findsNothing);
      expect(find.text('Last 24h'), findsNothing);
    });
  });
}
