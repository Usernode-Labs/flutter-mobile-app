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
        body: Center(child: child),
      ),
    );
  }

  group('Button', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'View in Leaderboard'),
      ));

      expect(find.text('View in Leaderboard'), findsOneWidget);
    });

    testWidgets('onTap fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        Button(
          label: 'Tap Me',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });

    testWidgets('renders leading icon when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const Button(
          label: 'With Icon',
          leadingIcon: Icon(Icons.arrow_forward, size: 20),
        ),
      ));

      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.text('With Icon'), findsOneWidget);
    });

    testWidgets('does not render icon space when no leadingIcon',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Button(label: 'No Icon'),
      ));

      // Should only find the button text, no icon widgets
      expect(find.byType(Icon), findsNothing);
    });
  });
}
