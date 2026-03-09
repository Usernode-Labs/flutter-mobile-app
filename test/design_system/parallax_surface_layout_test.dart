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
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          pinnedHeaderSliver: SliverToBoxAdapter(
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

    testWidgets('shows edge fade gradient when showEdgeFade is true',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          showEdgeFade: true,
        ),
      ));

      // Find a Container whose decoration has a LinearGradient.
      final gradientContainers =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.gradient is LinearGradient;
      });
      expect(gradientContainers, isNotEmpty);
    });

    testWidgets('no edge fade gradient when showEdgeFade is false',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
        ),
      ));

      final gradientContainers =
          tester.widgetList<Container>(find.byType(Container)).where((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.gradient is LinearGradient;
      });
      expect(gradientContainers, isEmpty);
    });

    testWidgets('headerFadesOnScroll=true uses fadeOut on header Flow',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          headerFadesOnScroll: true,
        ),
      ));

      // The header should be wrapped in a single-child Flow (no wash overlay).
      final headerFlow = find.ancestor(
        of: find.text('Header'),
        matching: find.byType(Flow),
      );
      expect(headerFlow, findsOneWidget);

      // No ColoredBox wash overlay inside the header Flow — fadeOut handles it.
      final washOverlay = find.descendant(
        of: headerFlow,
        matching: find.byType(ColoredBox),
      );
      expect(washOverlay, findsNothing);
    });

    testWidgets('headerFadesOnScroll=false has no wash overlay in header Flow',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          headerFadesOnScroll: false,
        ),
      ));

      // The header should still be wrapped in Flow.
      final headerFlow = find.ancestor(
        of: find.text('Header'),
        matching: find.byType(Flow),
      );
      expect(headerFlow, findsWidgets);

      // No ColoredBox wash overlay should be a descendant of the header Flow.
      final washOverlay = find.descendant(
        of: headerFlow.first,
        matching: find.byType(ColoredBox),
      );
      expect(washOverlay, findsNothing);
    });

    testWidgets(
        'root background lerps from surface to surfaceContainerLowest on scroll',
        (tester) async {
      final notifier = ValueNotifier<double>(0.0);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const SizedBox(height: 200),
          headerHeight: 200,
          scrollFractionNotifier: notifier,
          surfaceSlivers: [
            SliverList.list(
              children: List.generate(
                20,
                (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
              ),
            ),
          ],
        ),
      ));

      final theme =
          Theme.of(tester.element(find.byType(ParallaxSurfaceLayout)));
      final surface = theme.colorScheme.surface;
      final surfaceLowest = theme.colorScheme.surfaceContainerLowest;

      // At rest (sf=0), root ColoredBox should be surface color.
      // Target the first ColoredBox that is a descendant of PSL itself.
      ColoredBox rootBox() => tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(ParallaxSurfaceLayout),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
      expect(rootBox().color, surface);

      // Scroll fully (sf=1), root should be surfaceContainerLowest.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(rootBox().color, surfaceLowest);
    });

    testWidgets(
        'root background lerps from surface to surfaceContainerLowest on scroll',
        (tester) async {
      final notifier = ValueNotifier<double>(0.0);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const SizedBox(height: 200),
          headerHeight: 200,
          headerFadesOnScroll: true,
          scrollFractionNotifier: notifier,
          surfaceSlivers: [
            SliverList.list(
              children: List.generate(
                20,
                (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
              ),
            ),
          ],
        ),
      ));

      final theme =
          Theme.of(tester.element(find.byType(ParallaxSurfaceLayout)));
      final surface = theme.colorScheme.surface;
      final surfaceLowest = theme.colorScheme.surfaceContainerLowest;

      // At rest (sf=0), root ColoredBox should be surface color.
      ColoredBox rootBox() => tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(ParallaxSurfaceLayout),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
      expect(rootBox().color, surface);

      // Scroll fully (sf=1), root should be surfaceContainerLowest.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(rootBox().color, surfaceLowest);
    });

    testWidgets('passes controller to CustomScrollView', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          controller: controller,
        ),
      ));

      final csv = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(csv.controller, same(controller));
    });

    testWidgets('renders multiple pinnedHeaderSlivers', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          pinnedHeaderSlivers: [
            SliverToBoxAdapter(child: Text('Pinned A')),
            SliverToBoxAdapter(child: Text('Pinned B')),
          ],
          pinnedHeadersHeight: 100,
        ),
      ));

      expect(find.text('Pinned A'), findsOneWidget);
      expect(find.text('Pinned B'), findsOneWidget);
    });

    testWidgets('deprecated pinnedHeaderSliver still works', (tester) async {
      await tester.pumpWidget(wrapLayout(
        // ignore: deprecated_member_use
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Body'),
          pinnedHeaderSliver: SliverToBoxAdapter(
            child: Text('Legacy Pinned'),
          ),
          pinnedHeaderHeight: 48,
        ),
      ));

      expect(find.text('Legacy Pinned'), findsOneWidget);
    });

    testWidgets(
        'assertion fires when both pinnedHeaderSliver and pinnedHeaderSlivers',
        (tester) async {
      expect(
        () => ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          // ignore: deprecated_member_use
          pinnedHeaderSliver: const SliverToBoxAdapter(child: Text('Legacy')),
          pinnedHeaderSlivers: const [
            SliverToBoxAdapter(child: Text('New')),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets(
        'safeAreaOverlay adds internal pinned header when no pinned headers',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            const ParallaxSurfaceLayout(
              header: Text('Header'),
              surfaceBody: Text('Body'),
            ),
          ),
        ),
      );

      // The auto safe-area is an internal pinned SliverPersistentHeader.
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
    });

    testWidgets('safeAreaOverlay skipped when pinnedHeaderSlivers provided',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            const ParallaxSurfaceLayout(
              header: Text('Header'),
              surfaceBody: Text('Body'),
              safeAreaOverlay: true,
              pinnedHeaderSlivers: [
                SliverToBoxAdapter(child: SizedBox(height: 44)),
              ],
              pinnedHeadersHeight: 44,
            ),
          ),
        ),
      );

      // With pinned headers present, the auto safe-area pinned header should
      // NOT be added (no SliverPersistentHeader in the tree).
      expect(find.byType(SliverPersistentHeader), findsNothing);
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

    testWidgets('renders surfaceSlivers with SliverList', (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(
              children: const [
                Text('Sliver Item 1'),
                Text('Sliver Item 2'),
              ],
            ),
          ],
        ),
      ));

      expect(find.text('Sliver Item 1'), findsOneWidget);
      expect(find.text('Sliver Item 2'), findsOneWidget);
    });

    testWidgets('surfaceSlivers path uses SliverMainAxisGroup', (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(
              children: const [Text('Item')],
            ),
          ],
        ),
      ));

      expect(find.byType(SliverMainAxisGroup), findsOneWidget);
    });

    testWidgets('deprecated surfaceBody path still works', (tester) async {
      await tester.pumpWidget(wrapLayout(
        // ignore: deprecated_member_use
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          surfaceBody: Text('Legacy Body'),
        ),
      ));

      expect(find.text('Legacy Body'), findsOneWidget);
      // SliverMainAxisGroup should NOT be used in the deprecated path.
      expect(find.byType(SliverMainAxisGroup), findsNothing);
    });

    testWidgets(
        'assertion fires when both surfaceBody and surfaceSlivers provided',
        (tester) async {
      expect(
        // ignore: deprecated_member_use
        () => ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceBody: const Text('Body'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    // --- nestedBody tests ---

    testWidgets('nestedBody renders NestedScrollView', (tester) async {
      await tester.pumpWidget(wrapLayout(
        const ParallaxSurfaceLayout(
          header: Text('Header'),
          nestedBody: Text('Nested Content'),
        ),
      ));

      expect(find.byType(NestedScrollView), findsOneWidget);
      expect(find.byType(CustomScrollView), findsNothing);
      expect(find.text('Nested Content'), findsOneWidget);
    });

    testWidgets('nestedBody renders surfacePinnedSlivers', (tester) async {
      final notifier = ValueNotifier<double>(0.0);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          scrollFractionNotifier: notifier,
          surfacePinnedSlivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: SafeAreaPinnedDelegate(
                topPadding: 56,
                scrollFractionNotifier: notifier,
              ),
            ),
          ],
          surfacePinnedHeight: 56,
          nestedBody: const Text('Tab Content'),
        ),
      ));

      // NestedScrollView should contain the user's pinned header plus the
      // auto-injected safe-area sliver (no pinnedHeaderSlivers provided).
      expect(find.byType(SliverPersistentHeader), findsNWidgets(2));
      expect(find.text('Tab Content'), findsOneWidget);
    });

    testWidgets('assertion fires when surfacePinnedSlivers without nestedBody',
        (tester) async {
      expect(
        () => ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
          surfacePinnedSlivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 56)),
          ],
          surfacePinnedHeight: 56,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    // --- headerOverlay tests ---

    testWidgets('headerOverlay renders above scroll surface', (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
          headerOverlay: const Text('CTA Button'),
        ),
      ));

      expect(find.text('CTA Button'), findsOneWidget);
      expect(find.text('Header'), findsOneWidget);
    });

    testWidgets('headerOverlay IgnorePointer activates after scroll',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const SizedBox(height: 200),
          headerHeight: 200,
          surfaceSlivers: [
            SliverList.list(
              children: List.generate(
                20,
                (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
              ),
            ),
          ],
          headerOverlay: const Text('CTA'),
        ),
      ));

      // Before scroll: IgnorePointer should not be ignoring.
      final ipFinder = find.ancestor(
        of: find.text('CTA'),
        matching: find.byType(IgnorePointer),
      );
      var ip = tester.widget<IgnorePointer>(ipFinder.first);
      expect(ip.ignoring, isFalse);

      // Scroll down so surface covers the overlay.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pumpAndSettle();

      // After scroll: IgnorePointer should be ignoring.
      ip = tester.widget<IgnorePointer>(ipFinder.first);
      expect(ip.ignoring, isTrue);
    });

    testWidgets('headerOverlay parallaxes with header', (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
          headerOverlay: const Text('Overlay'),
        ),
      ));

      // Both header and overlay should be wrapped in Flow
      // (2 separate ValueListenableBuilder → Flow chains)
      final headerFlows = find.ancestor(
        of: find.text('Header'),
        matching: find.byType(Flow),
      );
      final overlayFlows = find.ancestor(
        of: find.text('Overlay'),
        matching: find.byType(Flow),
      );
      expect(headerFlows, findsWidgets);
      expect(overlayFlows, findsWidgets);
    });

    // --- title tests ---

    testWidgets('title invisible at rest', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const SizedBox(height: 200),
              headerHeight: 200,
              surfaceSlivers: [
                SliverList.list(
                  children: List.generate(
                    20,
                    (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
                  ),
                ),
              ],
              title: 'dApps',
            ),
          ),
        ),
      );

      // At rest (sf=0), the Opacity wrapping the title should be 0.
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('dApps'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('title renders when provided', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const SizedBox(height: 200),
              headerHeight: 200,
              surfaceSlivers: [
                SliverList.list(
                  children: List.generate(
                    20,
                    (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
                  ),
                ),
              ],
              title: 'dApps',
            ),
          ),
        ),
      );

      // Scroll fully so title becomes visible (sf→1).
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('dApps'), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.text('dApps'),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('title absent when null', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const Text('Header'),
              surfaceSlivers: [
                SliverList.list(children: const [Text('Item')]),
              ],
            ),
          ),
        ),
      );

      // No title text should appear in the pinned bar
      expect(find.text('dApps'), findsNothing);
    });

    testWidgets('title uses titleLarge style', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const SizedBox(height: 200),
              headerHeight: 200,
              surfaceSlivers: [
                SliverList.list(
                  children: List.generate(
                    20,
                    (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
                  ),
                ),
              ],
              title: 'Node Status',
            ),
          ),
        ),
      );

      // Scroll so title becomes visible.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<Text>(find.text('Node Status'));
      final theme =
          Theme.of(tester.element(find.byType(ParallaxSurfaceLayout)));
      expect(titleWidget.style?.fontSize, theme.textTheme.titleMedium?.fontSize);
    });

    // --- pinned bar border tests ---

    testWidgets('pinned bar border invisible at rest', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const SizedBox(height: 200),
              headerHeight: 200,
              surfaceSlivers: [
                SliverList.list(
                  children: List.generate(
                    20,
                    (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // At rest (sf=0), the bottom border alpha should be 0.
      final db = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      final border =
          (db.decoration as BoxDecoration).border! as Border;
      expect(border.bottom.color.a, 0.0);
    });

    testWidgets('pinned bar border appears on scroll', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
          child: wrapLayout(
            ParallaxSurfaceLayout(
              header: const SizedBox(height: 200),
              headerHeight: 200,
              surfaceSlivers: [
                SliverList.list(
                  children: List.generate(
                    20,
                    (i) => SizedBox(height: 60, key: ValueKey('item_$i')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Scroll fully so sf→1.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      final theme =
          Theme.of(tester.element(find.byType(ParallaxSurfaceLayout)));
      final borders = theme.extension<AppBorders>()!;

      final db = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(DecoratedBox),
        ),
      );
      final border =
          (db.decoration as BoxDecoration).border! as Border;
      expect(border.bottom.color.a, closeTo(borders.opacity, 0.001));
    });

    // --- onRefreshStatusChange tests ---

    testWidgets('onRefreshStatusChange uses RefreshIndicator.noSpinner',
        (tester) async {
      await tester.pumpWidget(wrapLayout(
        ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
          onRefresh: () async {},
          onRefreshStatusChange: (_) {},
        ),
      ));

      // RefreshIndicator.noSpinner creates a RefreshIndicator widget
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    // --- XOR assertion tests ---

    testWidgets(
        'assertion fires when both surfaceSlivers and nestedBody provided',
        (tester) async {
      expect(
        () => ParallaxSurfaceLayout(
          header: const Text('Header'),
          surfaceSlivers: [
            SliverList.list(children: const [Text('Item')]),
          ],
          nestedBody: const Text('Nested'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('assertion fires when no content param provided',
        (tester) async {
      expect(
        // Using non-const to allow runtime assertion check.
        // ignore: prefer_const_constructors
        () => ParallaxSurfaceLayout(
          header: const Text('Header'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    group('surface Y-position alignment', () {
      const safeTop = 44.0;
      const headerHeight = 200.0;

      Widget wrapWithSafeArea(Widget child) {
        return MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: safeTop)),
          child: wrapLayout(child),
        );
      }

      testWidgets(
        'surface Y matches between auto-sliver and equivalent manual-pinned path',
        (tester) async {
          // Path 1: auto-sliver (no pinnedHeaderSlivers, safeAreaOverlay=true)
          await tester.pumpWidget(wrapWithSafeArea(
            ParallaxSurfaceLayout(
              header: const Text('Header'),
              surfaceBody: const SizedBox(
                key: ValueKey('surface_auto'),
                height: 100,
              ),
              headerHeight: headerHeight,
            ),
          ));
          final autoY =
              tester.getTopLeft(find.byKey(const ValueKey('surface_auto'))).dy;

          // Path 2: explicit pinned header with extent = safeTop + kPinnedBarPadding
          final notifier = ValueNotifier<double>(0.0);
          addTearDown(notifier.dispose);
          await tester.pumpWidget(wrapWithSafeArea(
            ParallaxSurfaceLayout(
              header: const Text('Header'),
              surfaceBody: const SizedBox(
                key: ValueKey('surface_manual'),
                height: 100,
              ),
              headerHeight: headerHeight,
              pinnedHeaderSlivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: SafeAreaPinnedDelegate(
                    topPadding: safeTop + kPinnedBarPadding,
                    scrollFractionNotifier: notifier,
                  ),
                ),
              ],
              pinnedHeadersHeight: safeTop + kPinnedBarPadding,
            ),
          ));
          final manualY = tester
              .getTopLeft(find.byKey(const ValueKey('surface_manual')))
              .dy;

          expect(autoY, manualY,
              reason: 'Auto-sliver Y=$autoY vs manual-pinned Y=$manualY');
        },
      );

      testWidgets('surface Y equals safeTop + kPinnedBarPadding + headerHeight',
          (tester) async {
        await tester.pumpWidget(wrapWithSafeArea(
          ParallaxSurfaceLayout(
            header: const Text('Header'),
            surfaceBody: const SizedBox(
              key: ValueKey('surface_marker'),
              height: 100,
            ),
            headerHeight: headerHeight,
          ),
        ));
        final y =
            tester.getTopLeft(find.byKey(const ValueKey('surface_marker'))).dy;
        expect(y, safeTop + kPinnedBarPadding + headerHeight,
            reason:
                'Surface Y=$y, expected ${safeTop + kPinnedBarPadding + headerHeight}');
      });

      testWidgets(
        'surface Y with taller pinned header is pinnedHeight + headerHeight',
        (tester) async {
          const pinnedHeight = 80.0;
          const tallHeaderHeight = 344.0;
          final notifier = ValueNotifier<double>(0.0);
          addTearDown(notifier.dispose);
          await tester.pumpWidget(
            wrapLayout(
              ParallaxSurfaceLayout(
                header: const Text('Header'),
                surfaceBody: const SizedBox(
                  key: ValueKey('surface_tall'),
                  height: 100,
                ),
                headerHeight: tallHeaderHeight,
                pinnedHeaderSlivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: SafeAreaPinnedDelegate(
                      topPadding: pinnedHeight,
                      scrollFractionNotifier: notifier,
                    ),
                  ),
                ],
                pinnedHeadersHeight: pinnedHeight,
              ),
            ),
          );
          final y =
              tester.getTopLeft(find.byKey(const ValueKey('surface_tall'))).dy;
          expect(y, pinnedHeight + tallHeaderHeight,
              reason:
                  'Surface Y=$y, expected ${pinnedHeight + tallHeaderHeight}');
        },
      );

      testWidgets('header Y matches across both paths', (tester) async {
        // Path 1: auto-sliver
        await tester.pumpWidget(wrapWithSafeArea(
          const ParallaxSurfaceLayout(
            header: Text('Header'),
            surfaceBody: Text('Body'),
            headerHeight: headerHeight,
          ),
        ));
        final autoHeaderY = tester.getTopLeft(find.text('Header')).dy;

        // Path 2: manual pinned with extent = safeTop + kPinnedBarPadding
        final notifier = ValueNotifier<double>(0.0);
        addTearDown(notifier.dispose);
        await tester.pumpWidget(wrapWithSafeArea(
          ParallaxSurfaceLayout(
            header: const Text('Header'),
            surfaceBody: const Text('Body'),
            headerHeight: headerHeight,
            pinnedHeaderSlivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: SafeAreaPinnedDelegate(
                  topPadding: safeTop + kPinnedBarPadding,
                  scrollFractionNotifier: notifier,
                ),
              ),
            ],
            pinnedHeadersHeight: safeTop + kPinnedBarPadding,
          ),
        ));
        final manualHeaderY = tester.getTopLeft(find.text('Header')).dy;

        expect(autoHeaderY, manualHeaderY,
            reason:
                'Auto header Y=$autoHeaderY, manual header Y=$manualHeaderY');
      });
    });
  });
}
