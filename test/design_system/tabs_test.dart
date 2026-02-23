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

  final testTabs = const [
    TabItem(label: 'Active', badgeCount: 2),
    TabItem(label: 'Completed', badgeCount: 1),
    TabItem(label: 'Missed'),
  ];

  List<Widget> testChildren() => const [
        Center(child: Text('Active content')),
        Center(child: Text('Completed content')),
        Center(child: Text('Missed content')),
      ];

  group('Tabs', () {
    testWidgets('renders all tab labels', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
    });

    testWidgets('renders badge counts when present', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('hides badge when count is null', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'One'),
            TabItem(label: 'Two'),
          ],
          children: const [
            Center(child: Text('One content')),
            Center(child: Text('Two content')),
          ],
        ),
      ));

      // No badge containers should exist (no digit text)
      expect(find.byType(ShapeDecoration).evaluate(), isEmpty);
    });

    testWidgets('hides badge when count is zero', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Tab', badgeCount: 0),
          ],
          children: const [
            Center(child: Text('Content')),
          ],
        ),
      ));

      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows initial content page', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      expect(find.text('Active content'), findsOneWidget);
    });

    testWidgets('shows content at initialIndex', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          initialIndex: 1,
          children: testChildren(),
        ),
      ));

      expect(find.text('Completed content'), findsOneWidget);
    });

    testWidgets('tab tap switches content and fires callback', (tester) async {
      int? changedTo;
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          children: testChildren(),
          onTabChanged: (index) => changedTo = index,
        ),
      ));

      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(changedTo, equals(1));
      expect(find.text('Completed content'), findsOneWidget);
    });

    testWidgets('tapping already-selected tab does nothing', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          children: testChildren(),
          onTabChanged: (_) => callCount++,
        ),
      ));

      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();

      expect(callCount, equals(0));
    });

    testWidgets('has correct tab bar height of 48', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      // The SizedBox wrapping the tab bar should be 48dp
      final sizedBoxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(Tabs),
          matching: find.byType(SizedBox),
        ),
      );
      final tabBarBox = sizedBoxes.firstWhere(
        (sb) => sb.height == 48,
        orElse: () => throw TestFailure('No SizedBox with height 48 found'),
      );
      expect(tabBarBox.height, equals(48));
    });

    testWidgets('has divider below tab bar', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      // Find the 1px divider container
      final containers = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Tabs),
          matching: find.byType(Container),
        ),
      );
      final divider = containers.where(
        (c) => c.constraints?.maxHeight == 1 && c.constraints?.minHeight == 1,
      );
      expect(divider, isNotEmpty);
    });

    testWidgets('renders in scrollable mode', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          isScrollable: true,
          children: testChildren(),
        ),
      ));

      expect(find.text('Active'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('fixed mode uses equal-width Expanded tabs', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      // In fixed mode, we should not have SingleChildScrollView
      expect(find.byType(SingleChildScrollView), findsNothing);
      // But should have Expanded widgets for each tab
      expect(find.byType(Expanded), findsWidgets);
    });

    testWidgets('swipe changes tab', (tester) async {
      int? changedTo;
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          children: testChildren(),
          onTabChanged: (index) => changedTo = index,
        ),
      ));

      // Swipe left to go to next tab
      await tester.fling(
        find.byType(PageView),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(changedTo, equals(1));
    });
  });
}
