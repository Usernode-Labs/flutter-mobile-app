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

  group('AtomicChallengeCard', () {
    testWidgets('renders title, left and right text', (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Give kudos',
          leftText: '2 / 5',
          rightText: '400 / 1,500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 0.4,
          onTap: () {},
        ),
      ));

      expect(find.text('Give kudos'), findsOneWidget);
      // The fraction left text is rendered via Text.rich; the reward text is plain.
      expect(find.text('400 / 1,500 pts'), findsWidgets);
    });

    testWidgets('uses container card radius and full rail shape',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Give kudos',
          leftText: '2 / 5',
          rightText: '400 / 1,500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 0.4,
          onTap: () {},
        ),
      ));

      final radii = AppRadii.standard();
      final cardMaterial = tester.widget<Material>(
        find.descendant(
          of: find.byType(AtomicChallengeCard),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Material && widget.shape is RoundedRectangleBorder,
          ),
        ),
      );
      final cardShape = cardMaterial.shape! as RoundedRectangleBorder;
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );

      expect(cardShape.borderRadius, radii.borderRadiusLargeIncreased);
      expect(indicator.borderRadius, radii.borderRadiusFull);
    });

    testWidgets('whole card is tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Fill in survey',
          leftText: 'Not done',
          rightText: '500 pts',
          phase: AtomicChallengePhase.open,
          fill: 0,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byType(AtomicChallengeCard));
      expect(tapped, isTrue);
    });

    testWidgets('checkbox rail shows unchecked icon when not completed',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Fill in survey',
          leftText: 'Not done',
          rightText: '500 pts',
          phase: AtomicChallengePhase.open,
          fill: 0,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () {},
        ),
      ));

      expect(
        find.byIcon(Symbols.radio_button_unchecked_sharp),
        findsOneWidget,
      );
    });

    testWidgets('checkbox rail uses a fully rounded shape', (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Fill in survey',
          leftText: 'Not done',
          rightText: '500 pts',
          phase: AtomicChallengePhase.open,
          fill: 0,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () {},
        ),
      ));

      final radii = AppRadii.standard();
      final railDecorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(AtomicChallengeCard),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();

      expect(
        railDecorations.any(
          (decoration) => decoration.borderRadius == radii.borderRadiusFull,
        ),
        isTrue,
      );
    });

    testWidgets('checkbox rail shows selected icon when pending',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Share feedback',
          leftText: 'Submitted',
          rightText: 'pending 500 pts',
          phase: AtomicChallengePhase.pendingFinalization,
          fill: null,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Symbols.radio_button_checked_sharp), findsOneWidget);
      expect(find.byIcon(Symbols.radio_button_unchecked_sharp), findsNothing);
      expect(find.byIcon(Symbols.task_alt_sharp), findsNothing);
    });

    testWidgets('checkbox rail shows completed icon when completed',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Fill in survey',
          leftText: 'Done',
          rightText: '500 pts',
          phase: AtomicChallengePhase.completed,
          fill: 1,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () {},
        ),
      ));

      expect(find.byIcon(Symbols.task_alt_sharp), findsOneWidget);
    });

    testWidgets('checkbox rail uses filled success surface when completed',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Fill in survey',
          leftText: 'Done',
          rightText: 'completed 500 pts',
          phase: AtomicChallengePhase.completed,
          fill: null,
          railTreatment: AtomicChallengeRailTreatment.checkbox,
          onTap: () {},
        ),
      ));

      final semantic = AppSemanticColors.light();
      final railDecorations = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>();

      expect(
        railDecorations.any(
          (decoration) => decoration.color == semantic.success.color,
        ),
        isTrue,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.task_alt_sharp)).color,
        semantic.success.onColor,
      );
    });

    testWidgets('null fill renders a state-only rail (no progress indicator)',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Propose an app change',
          leftText: 'Submitted',
          rightText: 'waiting review',
          phase: AtomicChallengePhase.pendingFinalization,
          fill: null,
          onTap: () {},
        ),
      ));

      expect(find.text('waiting review'), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // null fill must not paint fake progress.
      expect(indicator.value, 0.0);
    });

    testWidgets('out-of-range fill is clamped to 0..1', (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Give kudos',
          leftText: '9 / 5',
          rightText: '400 / 1,500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 1.8,
          onTap: () {},
        ),
      ));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 1.0);
    });

    testWidgets('in-progress rail uses rich success fill with readable overlay',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Give kudos',
          leftText: '2 / 5',
          rightText: '400 / 1,500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 0.4,
          onTap: () {},
        ),
      ));

      final semantic = AppSemanticColors.light();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final rightLabelColors = tester
          .widgetList<Text>(find.text('400 / 1,500 pts'))
          .map((widget) => widget.style?.color)
          .toList();

      expect(indicator.color, semantic.success.color);
      expect(rightLabelColors, contains(semantic.success.onColor));
    });

    testWidgets('technicalOngoing rail renders an animated ongoing frame',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Produce Every Block',
          leftText: '90% success',
          rightText: 'Earned 10,550.1 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: null,
          railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
          onTap: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(OngoingRailFrame), findsOneWidget);
    });

    testWidgets('list-item treatment omits the Card container', (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Use dApps',
          leftText: '7 / 20',
          rightText: '350 / 1,000 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 0.35,
          cardTreatment: AtomicChallengeCardTreatment.listItem,
          onTap: () {},
        ),
      ));

      expect(find.byType(Card), findsNothing);
      expect(find.text('Use dApps'), findsOneWidget);
    });

    testWidgets(
        'featured in-progress rail without visible fill keeps text readable',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Open-ended kudos',
          leftText: '2 recognized kudos actions',
          rightText: '400 / 1,500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: null,
          featured: true,
          onTap: () {},
        ),
      ));

      final semantic = AppSemanticColors.light();
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      final leftText = tester.widget<Text>(
        find.text('2 recognized kudos actions'),
      );
      final rightText = tester.widget<Text>(find.text('400 / 1,500 pts'));

      expect(indicator.value, 0.0);
      expect(leftText.style?.color, semantic.premium.onColorSurface);
      expect(rightText.style?.color, semantic.premium.onColorSurface);
    });

    testWidgets('featured progress rail renders readable text across fill',
        (tester) async {
      await tester.pumpWidget(wrap(
        AtomicChallengeCard(
          title: 'Duplicate id event match',
          leftText: '1 / 5 Actions',
          rightText: '100 / 500 pts',
          phase: AtomicChallengePhase.inProgress,
          fill: 0.2,
          featured: true,
          onTap: () {},
        ),
      ));

      final semantic = AppSemanticColors.light();
      final leftLabels = tester
          .widgetList<Text>(find.text('1 / 5 Actions'))
          .map((widget) => widget.style?.color)
          .toList();

      expect(leftLabels, contains(semantic.premium.onColorSurface));
      expect(leftLabels, contains(semantic.premium.onColor));
    });
  });
}
