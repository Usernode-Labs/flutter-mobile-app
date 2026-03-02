import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

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
      home: Scaffold(body: child),
    );
  }

  group('FullPageErrorState', () {
    testWidgets('renders message and error icon', (tester) async {
      await tester.pumpWidget(wrap(
        const FullPageErrorState(message: 'Something went wrong'),
      ));

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Symbols.error_sharp), findsOneWidget);
    });

    testWidgets('renders detail when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const FullPageErrorState(
          message: 'Failed to load',
          detail: 'Connection timed out',
        ),
      ));

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Connection timed out'), findsOneWidget);
    });

    testWidgets('hides detail when null', (tester) async {
      await tester.pumpWidget(wrap(
        const FullPageErrorState(message: 'Error'),
      ));

      expect(find.text('Error'), findsOneWidget);
      // Only message text, no detail
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry provided', (tester) async {
      var retried = false;
      await tester.pumpWidget(wrap(
        FullPageErrorState(
          message: 'Error',
          onRetry: () => retried = true,
        ),
      ));

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(wrap(
        const FullPageErrorState(message: 'Error'),
      ));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('uses custom retry label', (tester) async {
      await tester.pumpWidget(wrap(
        FullPageErrorState(
          message: 'Error',
          onRetry: () {},
          retryLabel: 'Try Again',
        ),
      ));

      expect(find.text('Try Again'), findsOneWidget);
    });
  });
}
