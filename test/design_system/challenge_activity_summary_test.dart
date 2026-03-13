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

  group('ChallengeActivitySummary', () {
    testWidgets('shows "All caught up!" when completedCount > 0',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
        ),
      ));

      expect(find.text('All caught up!'), findsOneWidget);
      expect(
        find.text("You've tackled 7 of 10 challenges this season."),
        findsOneWidget,
      );
    });

    testWidgets('shows "No challenges completed" when completed=0 and missed>0',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 0,
          missedCount: 3,
          totalCount: 10,
        ),
      ));

      expect(find.text('No challenges completed'), findsOneWidget);
      expect(
        find.text("You've tackled 3 of 10 challenges this season."),
        findsOneWidget,
      );
    });

    testWidgets('shows "No challenges yet" and fallback summary when both 0',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 0,
          missedCount: 0,
          totalCount: 0,
        ),
      ));

      expect(find.text('No challenges yet'), findsOneWidget);
      expect(find.text('Check back soon for new challenges.'), findsOneWidget);
    });

    testWidgets('renders correct pill labels and icons', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
        ),
      ));

      expect(find.text('5 Done'), findsOneWidget);
      expect(find.text('2 Missed'), findsOneWidget);
      expect(find.byIcon(Symbols.check_circle), findsOneWidget);
      expect(find.byIcon(Symbols.disabled_by_default), findsOneWidget);
    });

    testWidgets('Done pill tap fires onViewCompleted', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
          onViewCompleted: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('5 Done'));
      expect(tapped, isTrue);
    });

    testWidgets('Missed pill tap fires onViewMissed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
          onViewMissed: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('2 Missed'));
      expect(tapped, isTrue);
    });

    testWidgets('no InkWell when callbacks are null', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
        ),
      ));

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('large numbers do not overflow', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 99999,
          missedCount: 99999,
          totalCount: 999999,
        ),
      ));

      // Should render without overflow errors
      expect(find.text('99999 Done'), findsOneWidget);
      expect(find.text('99999 Missed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders CustomPaint for shape cluster illustration',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
        ),
      ));

      // Find the CustomPaint that lives inside our 128px SizedBox.
      final illustrationBox = find.descendant(
        of: find.byType(ChallengeActivitySummary),
        matching: find.byWidgetPredicate(
          (w) => w is SizedBox && w.height == 128,
        ),
      );
      expect(illustrationBox, findsOneWidget);
      expect(
        find.descendant(
          of: illustrationBox,
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pills use IntrinsicWidth, not Expanded', (tester) async {
      await tester.pumpWidget(wrap(
        const ChallengeActivitySummary(
          completedCount: 5,
          missedCount: 2,
          totalCount: 10,
        ),
      ));

      expect(find.byType(IntrinsicWidth), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(ChallengeActivitySummary),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
    });
  });
}
