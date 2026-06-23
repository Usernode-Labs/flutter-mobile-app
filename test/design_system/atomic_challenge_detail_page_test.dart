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
    VoidCallback? onBack,
    VoidCallback? onCta,
  }) {
    return AtomicChallengeDetailPage(
      title: 'Propose an app change',
      description: 'Improve an existing dApp and help test the app layer.',
      leftText: 'Not done',
      rightText: '500 pts',
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
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Jun 4 - Jun 17'), findsOneWidget);
      expect(find.text('How points work'), findsOneWidget);
      expect(find.text('Join the challenge'), findsOneWidget);
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

    testWidgets('Rules section hidden when null, shown when provided',
        (tester) async {
      await tester.pumpWidget(wrap(page()));
      expect(find.text('Rules'), findsNothing);

      await tester.pumpWidget(wrap(page(rules: 'Keep your node connected.')));
      expect(find.text('Rules'), findsOneWidget);
    });
  });
}
