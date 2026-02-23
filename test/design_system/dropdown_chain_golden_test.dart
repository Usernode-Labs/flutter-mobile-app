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

  Widget wrap(Widget child, {double width = 360}) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  group('DropdownChain golden', () {
    testWidgets('two items', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(label: 'DApps Integration'),
        ]),
      ));

      await expectLater(
        find.byType(DropdownChain),
        matchesGoldenFile('goldens/dropdown_chain_two_items.png'),
      );
    });

    testWidgets('three items', (tester) async {
      await tester.pumpWidget(wrap(
        DropdownChain(items: const [
          DropdownChainItem(label: 'Season 2'),
          DropdownChainItem(label: 'DApps'),
          DropdownChainItem(label: 'Advanced'),
        ]),
        width: 500,
      ));

      await expectLater(
        find.byType(DropdownChain),
        matchesGoldenFile('goldens/dropdown_chain_three_items.png'),
      );
    });
  });
}
