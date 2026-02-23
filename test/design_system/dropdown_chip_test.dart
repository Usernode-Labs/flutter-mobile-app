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

  group('DropdownChip', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2'),
      ));

      expect(find.text('Season 2'), findsOneWidget);
    });

    testWidgets('renders dropdown icon', (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2'),
      ));

      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('fires onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        DropdownChip(
          label: 'Season 2',
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Season 2'));
      expect(tapped, isTrue);
    });

    testWidgets('does not crash when onTap is null', (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2'),
      ));

      await tester.tap(find.text('Season 2'));
      // No error means the test passes.
    });

    testWidgets('shrink-wraps by default (expanded: false)', (tester) async {
      await tester.pumpWidget(wrap(
        const Row(
          children: [
            DropdownChip(label: 'Season 2'),
          ],
        ),
      ));

      final chipSize = tester.getSize(find.byType(DropdownChip));
      // Shrink-wrapped chip should be narrower than the 360px parent.
      expect(chipSize.width, lessThan(360));
    });

    testWidgets('expands to fill available width when expanded: true',
        (tester) async {
      await tester.pumpWidget(wrap(
        const Row(
          children: [
            Expanded(
              child: DropdownChip(label: 'DApps Integration', expanded: true),
            ),
          ],
        ),
      ));

      final chipSize = tester.getSize(find.byType(DropdownChip));
      expect(chipSize.width, equals(360));
    });

    testWidgets('has correct height of 32', (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2'),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DropdownChip),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.maxHeight, equals(32));
    });

    testWidgets('selected: true applies secondaryContainer fill',
        (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2', selected: true),
      ));

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(DropdownChip),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      final theme = themeWithExtensions();
      expect(decoration.color, equals(theme.colorScheme.secondaryContainer));
    });

    testWidgets('enabled: false wraps in Opacity with disabled value',
        (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2', enabled: false),
      ));

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, equals(0.30));
    });

    testWidgets('enabled: false ignores onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        DropdownChip(
          label: 'Season 2',
          enabled: false,
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Season 2'));
      expect(tapped, isFalse);
    });
  });
}
