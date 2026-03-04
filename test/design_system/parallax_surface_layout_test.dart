import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrapLayout(Widget child) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(body: child),
    );
  }

  group('ParallaxSurfaceLayout', () {
    testWidgets('renders header and surface body', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
        ),
      ));

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('uses default headerHeight of 200', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
        ),
      ));

      // The SizedBox for the header spacer should be 200
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((sb) => sb.height == kDefaultHeaderHeight);
      expect(sizedBoxes, isNotEmpty);
    });

    testWidgets('custom headerHeight is respected', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          headerHeight: 300,
        ),
      ));

      final sizedBoxes = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((sb) => sb.height == 300.0);
      expect(sizedBoxes, isNotEmpty);
    });

    testWidgets('wraps in RefreshIndicator when onRefresh provided',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          onRefresh: () async {},
        ),
      ));

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('no RefreshIndicator when onRefresh is null', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
        ),
      ));

      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('renders pinnedHeaderSliver when provided', (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          pinnedHeaderSliver: const SliverToBoxAdapter(
            child: Text('Pinned'),
          ),
        ),
      ));

      expect(find.text('Pinned'), findsOneWidget);
    });

    testWidgets('uses external scrollFractionNotifier', (tester) async {
      final notifier = ValueNotifier<double>(0.0);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          scrollFractionNotifier: notifier,
        ),
      ));

      // Initially 0
      expect(notifier.value, 0.0);
    });

    testWidgets('uses CustomScrollView internally', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
        ),
      ));

      expect(find.byType(CustomScrollView), findsOneWidget);
    });
  });
}
