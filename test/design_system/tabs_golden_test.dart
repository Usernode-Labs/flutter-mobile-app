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
        body: SizedBox(
          height: 400,
          width: 360,
          child: child,
        ),
      ),
    );
  }

  group('Tabs golden', () {
    testWidgets('fixed with badges', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Active', badgeCount: 2),
            TabItem(label: 'Completed', badgeCount: 1),
            TabItem(label: 'Missed'),
          ],
          children: const [
            Center(child: Text('Active content')),
            Center(child: Text('Completed content')),
            Center(child: Text('Missed content')),
          ],
        ),
      ));

      await expectLater(
        find.byType(Tabs),
        matchesGoldenFile('goldens/tabs_fixed_badges.png'),
      );
    });

    testWidgets('fixed without badges', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Overview'),
            TabItem(label: 'Details'),
            TabItem(label: 'History'),
          ],
          children: const [
            Center(child: Text('Overview content')),
            Center(child: Text('Details content')),
            Center(child: Text('History content')),
          ],
        ),
      ));

      await expectLater(
        find.byType(Tabs),
        matchesGoldenFile('goldens/tabs_fixed_no_badges.png'),
      );
    });

    testWidgets('second tab selected', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Active', badgeCount: 2),
            TabItem(label: 'Completed', badgeCount: 1),
            TabItem(label: 'Missed'),
          ],
          initialIndex: 1,
          children: const [
            Center(child: Text('Active content')),
            Center(child: Text('Completed content')),
            Center(child: Text('Missed content')),
          ],
        ),
      ));

      await expectLater(
        find.byType(Tabs),
        matchesGoldenFile('goldens/tabs_second_selected.png'),
      );
    });

    testWidgets('scrollable mode', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Active', badgeCount: 2),
            TabItem(label: 'Completed', badgeCount: 1),
            TabItem(label: 'Missed'),
          ],
          isScrollable: true,
          children: const [
            Center(child: Text('Active content')),
            Center(child: Text('Completed content')),
            Center(child: Text('Missed content')),
          ],
        ),
      ));

      await expectLater(
        find.byType(Tabs),
        matchesGoldenFile('goldens/tabs_scrollable.png'),
      );
    });
  });
}
