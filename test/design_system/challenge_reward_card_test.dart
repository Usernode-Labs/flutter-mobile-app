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
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );
  }

  group('ChallengeRewardCard', () {
    testWidgets('renders total earned and points label', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeRewardCard(
          category: ChallengeCategory.technical,
          totalEarned: '10,550.1',
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 0.5,
          successRate: '50%',
          maxPoints: '1,000',
          totalPoints: '500',
          rankReward: '+100',
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
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 0.98,
          successRate: '98%',
          maxPoints: '5,000',
          totalPoints: '4,900',
          rankReward: '+0',
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
          progressFraction: 1.0,
          successRate: '100%',
          maxPoints: '100',
          totalPoints: '100',
          rankReward: '+0',
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
  });
}
