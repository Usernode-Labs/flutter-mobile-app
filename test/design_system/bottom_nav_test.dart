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

  final testItems = const [
    BottomNavItem(icon: Symbols.home_sharp, label: 'Home'),
    BottomNavItem(icon: Symbols.search_sharp, label: 'Search'),
    BottomNavItem(icon: Symbols.settings_sharp, label: 'Settings'),
  ];

  group('BottomNav', () {
    testWidgets('renders all item labels', (tester) async {
      await tester.pumpWidget(wrap(
        BottomNav(items: testItems, selectedIndex: 0),
      ));

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('selected icon has fill 1', (tester) async {
      await tester.pumpWidget(wrap(
        BottomNav(items: testItems, selectedIndex: 0),
      ));

      // The selectedIcon for index 0 should have fill: 1
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      // NavigationBar renders icon for unselected, selectedIcon for selected.
      // The selected destination's icon should have fill == 1.
      final filledIcons = icons.where((icon) => icon.fill == 1);
      expect(filledIcons, isNotEmpty);
    });

    testWidgets('unselected icon has fill 0', (tester) async {
      await tester.pumpWidget(wrap(
        BottomNav(items: testItems, selectedIndex: 0),
      ));

      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final outlineIcons = icons.where((icon) => icon.fill == 0);
      expect(outlineIcons, isNotEmpty);
    });

    testWidgets('selected icon uses indicatorColor when set', (tester) async {
      const indicatorColor = Color(0xFFFF0000);
      final items = [
        const BottomNavItem(
          icon: Symbols.home_sharp,
          label: 'Home',
          indicatorColor: indicatorColor,
        ),
        const BottomNavItem(icon: Symbols.search_sharp, label: 'Search'),
      ];

      await tester.pumpWidget(wrap(
        BottomNav(items: items, selectedIndex: 0),
      ));

      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final filledIcon = icons.firstWhere((icon) => icon.fill == 1);
      expect(filledIcon.color, equals(indicatorColor));
    });

    testWidgets('unselected icon uses outline color', (tester) async {
      await tester.pumpWidget(wrap(
        BottomNav(items: testItems, selectedIndex: 0),
      ));

      final theme = themeWithExtensions();
      final outlineColor = theme.colorScheme.outline;

      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final outlineIcons = icons.where((icon) => icon.fill == 0);
      for (final icon in outlineIcons) {
        expect(icon.color, equals(outlineColor));
      }
    });

    testWidgets('onItemSelected fires with correct index', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(wrap(
        BottomNav(
          items: testItems,
          selectedIndex: 0,
          onItemSelected: (index) => selectedIndex = index,
        ),
      ));

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(1));
    });

    testWidgets('disabled item does not fire callback', (tester) async {
      int? selectedIndex;
      final items = [
        const BottomNavItem(icon: Symbols.home_sharp, label: 'Home'),
        const BottomNavItem(
          icon: Symbols.search_sharp,
          label: 'Search',
          enabled: false,
        ),
      ];

      await tester.pumpWidget(wrap(
        BottomNav(
          items: items,
          selectedIndex: 0,
          onItemSelected: (index) => selectedIndex = index,
        ),
      ));

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(selectedIndex, isNull);
    });

    testWidgets('badge renders when badgeCount > 0', (tester) async {
      final items = [
        const BottomNavItem(
            icon: Symbols.home_sharp, label: 'Home', badgeCount: 5),
        const BottomNavItem(icon: Symbols.search_sharp, label: 'Search'),
      ];

      await tester.pumpWidget(wrap(
        BottomNav(items: items, selectedIndex: 0),
      ));

      expect(find.text('5'), findsWidgets);
      expect(find.byType(Badge), findsWidgets);
    });

    testWidgets('badge hidden when badgeCount is null', (tester) async {
      await tester.pumpWidget(wrap(
        BottomNav(items: testItems, selectedIndex: 0),
      ));

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('badge hidden when badgeCount is 0', (tester) async {
      final items = [
        const BottomNavItem(
            icon: Symbols.home_sharp, label: 'Home', badgeCount: 0),
        const BottomNavItem(icon: Symbols.search_sharp, label: 'Search'),
      ];

      await tester.pumpWidget(wrap(
        BottomNav(items: items, selectedIndex: 0),
      ));

      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('indicatorFillColor is used for indicator', (tester) async {
      const fillColor = Color(0x33FF0000);
      final items = [
        const BottomNavItem(
          icon: Symbols.home_sharp,
          label: 'Home',
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: Color(0xFFFF0000),
          indicatorFillColor: fillColor,
        ),
        const BottomNavItem(icon: Symbols.search_sharp, label: 'Search'),
      ];

      await tester.pumpWidget(wrap(
        BottomNav(items: items, selectedIndex: 0),
      ));

      // Find the NavigationBar and verify indicatorColor
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.indicatorColor, equals(fillColor));
    });
  });
}
