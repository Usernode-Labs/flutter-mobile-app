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

  final labels = ['Option A', 'Option B', 'Option C'];

  group('DropdownSheet', () {
    testWidgets('renders all option labels', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => showDropdownSheet(
              context: context,
              labels: labels,
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      for (final label in labels) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('renders title when provided', (tester) async {
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => showDropdownSheet(
              context: context,
              labels: labels,
              title: 'Pick one',
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Pick one'), findsOneWidget);
    });

    testWidgets('tapping an option returns its index', (tester) async {
      int? result;
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              result = await showDropdownSheet(
                context: context,
                labels: labels,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Option B'));
      await tester.pumpAndSettle();

      expect(result, equals(1));
    });

    testWidgets('tapping barrier dismisses and returns null', (tester) async {
      int? result = -1; // sentinel to distinguish null from not-called
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () async {
              result = await showDropdownSheet(
                context: context,
                labels: labels,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap the barrier (top-left corner, outside the sheet).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('selected option shows check icon, others do not',
        (tester) async {
      await tester.pumpWidget(wrap(
        Builder(
          builder: (context) => GestureDetector(
            onTap: () => showDropdownSheet(
              context: context,
              labels: labels,
              selectedIndex: 1,
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Only one check icon for the selected item.
      expect(find.byIcon(Symbols.check_sharp), findsOneWidget);
    });
  });
}
