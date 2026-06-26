import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: child,
    );
  }

  AtomicChallengeDetailPage page({
    String? rules,
    String? progressHelperText,
    AtomicChallengeTechnicalHeroCardData? heroCard,
    VoidCallback? onBack,
    VoidCallback? onCta,
  }) {
    return AtomicChallengeDetailPage(
      title: 'Propose an app change',
      description: 'Improve an existing dApp and help test the app layer.',
      task: 'Submit a small accepted change to a dApp.',
      leftText: 'Not done',
      rightText: '500 pts',
      progressHelperText: progressHelperText,
      heroCard: heroCard,
      phase: AtomicChallengePhase.open,
      fill: 0,
      dateText: 'Jun 4 - Jun 17',
      pointsLogic: 'Earn 500 pts when your proposed change is accepted.',
      ctaLabel: 'Join the challenge',
      rules: rules,
      railTreatment: AtomicChallengeRailTreatment.checkbox,
      onBackTap: onBack ?? () {},
      onCtaTap: onCta ?? () {},
    );
  }

  group('AtomicChallengeDetailPage', () {
    testWidgets('renders title, sections and CTA', (tester) async {
      await tester.pumpWidget(wrap(page()));

      expect(find.text('Propose an app change'), findsOneWidget);
      expect(find.text('Why it matters'), findsOneWidget);
      expect(find.text('Improve an existing dApp and help test the app layer.'),
          findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Submit a small accepted change to a dApp.'),
          findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Jun 4 - Jun 17'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('How points work'), 300);
      expect(find.text('How points work'), findsOneWidget);
      expect(find.text('Join the challenge'), findsOneWidget);
    });

    testWidgets('renders optional progress helper copy under the rail',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          page(
            progressHelperText: 'You submitted the feedback form.',
          ),
        ),
      );

      expect(
        find.text('You submitted the feedback form.'),
        findsOneWidget,
      );
    });

    testWidgets('back and CTA callbacks fire', (tester) async {
      var backed = false;
      var cta = false;
      await tester.pumpWidget(
        wrap(page(onBack: () => backed = true, onCta: () => cta = true)),
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.tap(find.text('Join the challenge'));
      expect(backed, isTrue);
      expect(cta, isTrue);
    });

    testWidgets('technical hero card renders formula, rail and overview rows',
        (tester) async {
      var networkTapped = false;

      await tester.pumpWidget(
        wrap(
          AtomicChallengeDetailPage(
            title: 'Produce Every Block',
            description: 'Keep your node ready when you win a slot.',
            leftText: '90% success',
            rightText: 'Earned 10,550 pts',
            phase: AtomicChallengePhase.inProgress,
            fill: null,
            railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
            heroCard: AtomicChallengeTechnicalHeroCardData(
              totalEarned: '10,550',
              formula: const AtomicChallengeHeroFormula(
                rateLabel: 'Success rate',
                rateValue: '90%',
                maxLabel: 'Assigned slots',
                maxValue: '5,000',
                totalLabel: 'Base reward',
                totalValue: '9,050',
              ),
              rewardLines: const [
                AtomicChallengeHeroRewardLine(
                  label: 'Top 3 rank reward',
                  badge: '2nd',
                  value: '+1,500',
                ),
                AtomicChallengeHeroRewardLine(
                  label: 'Last 24h',
                  value: '+250',
                ),
              ],
              epochLabel: 'View epoch 12 slots',
              onEpochTap: () {},
              overview: [
                AtomicChallengeHeroOverviewItem(
                  label: 'Network',
                  value: 'Connected',
                  icon: Icons.wifi,
                  tone: AtomicChallengeHeroOverviewTone.success,
                  onTap: () => networkTapped = true,
                ),
                const AtomicChallengeHeroOverviewItem(
                  label: 'Missed Blocks',
                  value: 'None',
                  icon: Icons.disabled_by_default,
                  tone: AtomicChallengeHeroOverviewTone.success,
                ),
              ],
            ),
            dateText: 'Season ends in 128d',
            pointsLogic: 'Score = success rate x assigned-slot points.',
            ctaLabel: 'Check node',
            onBackTap: () {},
            onCtaTap: () {},
          ),
        ),
      );

      expect(find.text('Total Earned'), findsOneWidget);
      expect(find.text('10,550'), findsOneWidget);
      expect(find.text('pts'), findsOneWidget);
      expect(find.text('90% success'), findsOneWidget);
      expect(find.text('Earned 10,550 pts'), findsOneWidget);
      expect(find.text('Success rate'), findsOneWidget);
      expect(find.text('Assigned slots'), findsOneWidget);
      expect(find.text('Base reward'), findsOneWidget);
      expect(find.text('Top 3 rank reward'), findsOneWidget);
      expect(find.text('2nd'), findsOneWidget);
      expect(find.text('+1,500'), findsOneWidget);
      expect(find.text('View epoch 12 slots'), findsOneWidget);
      expect(find.text('Live status'), findsOneWidget);
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Missed Blocks'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Network'));
      expect(networkTapped, isTrue);
    });

    testWidgets('Rules section hidden when null, shown when provided',
        (tester) async {
      await tester.pumpWidget(wrap(page()));
      expect(find.text('Rules'), findsNothing);

      await tester.pumpWidget(wrap(page(rules: 'Keep your node connected.')));
      await tester.scrollUntilVisible(find.text('Rules'), 300);
      expect(find.text('Rules'), findsOneWidget);
    });

    testWidgets('description and task sections hide independently',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          AtomicChallengeDetailPage(
            title: 'Complete 3 dApp actions',
            description: '',
            task: 'Perform 3 tracked test actions.',
            leftText: '1 / 3 Actions',
            rightText: '100 / 300 pts',
            phase: AtomicChallengePhase.inProgress,
            fill: 1 / 3,
            dateText: 'Jun 23 - Jun 25',
            pointsLogic: 'Earn 100 pts for each verified action.',
            ctaLabel: 'Open dApps',
            onBackTap: () {},
            onCtaTap: () {},
          ),
        ),
      );

      expect(find.text('Why it matters'), findsNothing);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Perform 3 tracked test actions.'), findsOneWidget);
    });
  });
}
