@Tags(['golden'])
library;

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

  group('DropdownChip golden', () {
    testWidgets('default (shrink-wrapped)', (tester) async {
      await tester.pumpWidget(wrap(
        const DropdownChip(label: 'Season 2'),
      ));

      await expectLater(
        find.byType(DropdownChip),
        matchesGoldenFile('goldens/dropdown_chip_default.png'),
      );
    });

    testWidgets('expanded', (tester) async {
      await tester.pumpWidget(wrap(
        const Row(
          children: [
            Expanded(
              child: DropdownChip(label: 'DApps Integration', expanded: true),
            ),
          ],
        ),
      ));

      await expectLater(
        find.byType(DropdownChip),
        matchesGoldenFile('goldens/dropdown_chip_expanded.png'),
      );
    });
  });
}
