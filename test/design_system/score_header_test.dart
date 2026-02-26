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

  group('ScoreHeader', () {
    testWidgets('renders score and label', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
        ),
      ));

      expect(find.text('8,000'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    testWidgets('renders rank label when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          rankLabel: 'Rank 44',
        ),
      ));

      expect(find.text('Rank 44'), findsOneWidget);
    });

    testWidgets('hides rank label when null', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
        ),
      ));

      expect(find.text('Rank 44'), findsNothing);
    });

    testWidgets('renders countdown row when countdownTime provided',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownTime: '12 DAYS 5H 3M',
        ),
      ));

      expect(find.text('ENDS IN'), findsOneWidget);
      expect(find.text('12 DAYS 5H 3M'), findsOneWidget);
    });

    testWidgets('shows countdown row with fallback when countdownTime is null',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
        ),
      ));

      // Countdown row is always visible; null time renders as "--"
      expect(find.text('ENDS IN'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('renders CTA button when ctaLabel provided', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          ctaLabel: 'View in Leaderboard',
        ),
      ));

      expect(find.text('View in Leaderboard'), findsOneWidget);
    });

    testWidgets('hides CTA button when ctaLabel is null', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
        ),
      ));

      expect(find.byType(Button), findsNothing);
    });

    testWidgets('onCtaTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          ctaLabel: 'View in Leaderboard',
          onCtaTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('View in Leaderboard'));
      expect(tapped, isTrue);
    });

    testWidgets('renders standard variant without error', (tester) async {
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

      expect(find.byType(ScoreHeader), findsOneWidget);
    });

    testWidgets('renders glow variant without error', (tester) async {
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

      expect(find.byType(ScoreHeader), findsOneWidget);
    });

    testWidgets('uses custom countdownLabel', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownLabel: 'STARTS IN',
          countdownTime: '2 DAYS',
        ),
      ));

      expect(find.text('STARTS IN'), findsOneWidget);
      expect(find.text('2 DAYS'), findsOneWidget);
    });

    testWidgets('countdownTextMode.caughtUp displays ALL CAUGHT UP! text',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownTime: '12 DAYS 5H 3M',
          countdownTextMode: CountdownTextMode.caughtUp,
        ),
      ));

      expect(find.text('ALL CAUGHT UP!'), findsOneWidget);
      expect(find.text('ENDS IN'), findsNothing);
      expect(find.text('12 DAYS 5H 3M'), findsNothing);
    });

    testWidgets('countdownTextMode.catchingUp displays CATCHING UP... text',
        (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownTime: '12 DAYS 5H 3M',
          countdownTextMode: CountdownTextMode.catchingUp,
        ),
      ));

      expect(find.text('CATCHING UP...'), findsOneWidget);
      expect(find.text('ENDS IN'), findsNothing);
      expect(find.text('12 DAYS 5H 3M'), findsNothing);
    });

    testWidgets('countdownOpacity 0 hides countdown text', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownTime: '12 DAYS 5H 3M',
          countdownOpacity: 0.0,
        ),
      ));

      // The text widgets exist but are fully transparent.
      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 0.0);
    });

    testWidgets('default countdown shows normally', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreHeader(
          score: '8,000',
          scoreLabel: 'points',
          countdownTime: '12 DAYS 5H 3M',
        ),
      ));

      expect(find.text('ENDS IN'), findsOneWidget);
      expect(find.text('12 DAYS 5H 3M'), findsOneWidget);
    });
  });
}
