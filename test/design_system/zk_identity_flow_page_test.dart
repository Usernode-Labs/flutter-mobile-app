import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

void main() {
  const steps = [
    ZkIdentityStepData(
      label: 'Check App',
      description: 'Checking app version',
      status: ZkIdentityStepVisualStatus.completed,
    ),
    ZkIdentityStepData(
      label: 'Scan',
      description: 'Scan your passport',
      status: ZkIdentityStepVisualStatus.active,
    ),
    ZkIdentityStepData(
      label: 'Verify',
      description: 'Verifying identity',
      status: ZkIdentityStepVisualStatus.pending,
    ),
  ];

  Widget buildApp({
    required List<ZkIdentityStepData> steps,
    int currentStepIndex = 0,
    bool centerActiveContent = false,
    Widget? activeStepContent,
    Widget? bottomAction,
    VoidCallback? onBack,
  }) {
    final textTheme = ThemeData.light().textTheme;
    final cieTheme = ColorIsExpensiveTheme(textTheme);
    final themeData = cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    return MaterialApp(
      theme: themeData,
      home: ZkIdentityFlowPage(
        steps: steps,
        currentStepIndex: currentStepIndex,
        centerActiveContent: centerActiveContent,
        activeStepContent: activeStepContent,
        bottomAction: bottomAction,
        onBack: onBack,
      ),
    );
  }

  // Uses pump() instead of pumpAndSettle() throughout — the
  // ZkIdentityStepIllustration has a looping AnimationController
  // that never settles.
  group('ZkIdentityFlowPage', () {
    testWidgets('renders step label and description', (tester) async {
      await tester.pumpWidget(buildApp(steps: steps, currentStepIndex: 1));
      await tester.pump();

      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Scan your passport'), findsOneWidget);
    });

    testWidgets('renders progress bar with decorated segments', (tester) async {
      await tester.pumpWidget(buildApp(steps: steps));
      await tester.pump();

      // Each step gets a decorated Container with color in the progress bar.
      final segments = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color != null,
      );
      expect(segments.evaluate().length, greaterThanOrEqualTo(3));
    });

    testWidgets('back button fires onBack callback', (tester) async {
      var backPressed = false;

      await tester.pumpWidget(
        buildApp(steps: steps, onBack: () => backPressed = true),
      );
      await tester.pump();

      await tester.tap(find.byType(IconButton));
      expect(backPressed, true);
    });

    testWidgets('renders bottom action in bottomNavigationBar', (tester) async {
      await tester.pumpWidget(
        buildApp(
          steps: steps,
          bottomAction: const Text('Continue'),
        ),
      );
      await tester.pump();

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('renders activeStepContent in normal mode', (tester) async {
      await tester.pumpWidget(
        buildApp(
          steps: steps,
          currentStepIndex: 1,
          activeStepContent: const Text('Custom content'),
        ),
      );
      await tester.pump();

      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Custom content'), findsOneWidget);
    });

    testWidgets('centered mode shows activeStepContent and hides label',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          steps: steps,
          currentStepIndex: 1,
          centerActiveContent: true,
          activeStepContent: const Text('Centered widget'),
        ),
      );
      await tester.pump();

      expect(find.text('Centered widget'), findsOneWidget);
      // Label/description hidden in centered mode.
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Scan your passport'), findsNothing);
    });

    testWidgets('centered mode uses CustomScrollView for overflow scroll',
        (tester) async {
      await tester.pumpWidget(
        buildApp(
          steps: steps,
          currentStepIndex: 1,
          centerActiveContent: true,
          activeStepContent: const Text('Content'),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverFillRemaining), findsOneWidget);
    });

    testWidgets('centered mode scrolls when content overflows', (tester) async {
      final tallContent = Column(
        children: List.generate(
          30,
          (i) => SizedBox(height: 50, child: Text('Row $i')),
        ),
      );

      await tester.pumpWidget(
        buildApp(
          steps: steps,
          currentStepIndex: 1,
          centerActiveContent: true,
          activeStepContent: tallContent,
        ),
      );
      await tester.pump();

      // All rows exist in the widget tree (SliverFillRemaining lays out fully).
      expect(find.text('Row 0'), findsOneWidget);
      expect(find.text('Row 29'), findsOneWidget);

      // Verify we can scroll without error (content exceeds viewport).
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
    });

    testWidgets('handles out-of-bounds step index gracefully', (tester) async {
      await tester.pumpWidget(
        buildApp(steps: steps, currentStepIndex: 99),
      );
      await tester.pump();

      expect(find.byType(ZkIdentityFlowPage), findsOneWidget);
    });
  });
}
