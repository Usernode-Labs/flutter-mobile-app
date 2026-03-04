import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
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

  const testTabs = [
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

      // No badge text should exist
      expect(find.text('0'), findsNothing);
    });

    testWidgets('hides badge when count is zero', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: const [
            TabItem(label: 'Tab', badgeCount: 0),
            TabItem(label: 'Other'),
          ],
          children: const [
            Center(child: Text('Content')),
            Center(child: Text('Other content')),
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

    testWidgets('renders M3 TabBar and TabBarView', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('has divider via TabBar by default', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.dividerHeight, equals(1));
    });

    testWidgets('hides divider when showDivider is false', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(
          tabs: testTabs,
          showDivider: false,
          children: testChildren(),
        ),
      ));

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.dividerHeight, equals(0));
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
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isTrue);
    });

    testWidgets('fixed mode fills available width', (tester) async {
      await tester.pumpWidget(wrap(
        Tabs(tabs: testTabs, children: testChildren()),
      ));

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isFalse);
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

      // Swipe left to go to next tab via TabBarView
      await tester.fling(
        find.byType(TabBarView),
        const Offset(-300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(changedTo, equals(1));
    });
  });
}
