import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget sliver) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            sliver,
            const SliverFillRemaining(
              child: Center(child: Text('Content')),
            ),
          ],
        ),
      ),
    );
  }

  group('TopAppBar - small', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(title: 'Leaderboard'),
      ));

      expect(find.text('Leaderboard'), findsOneWidget);
    });

    testWidgets('renders back arrow by default', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(title: 'Leaderboard'),
      ));

      expect(find.byIcon(Symbols.arrow_back_sharp), findsOneWidget);
    });

    testWidgets('fires onLeadingTap when back arrow is tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrap(
        TopAppBar(
          title: 'Leaderboard',
          onLeadingTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
      expect(tapped, isTrue);
    });

    testWidgets('renders custom leading widget', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Leaderboard',
          leading: Icon(Symbols.menu_sharp),
        ),
      ));

      expect(find.byIcon(Symbols.menu_sharp), findsOneWidget);
      expect(find.byIcon(Symbols.arrow_back_sharp), findsNothing);
    });

    testWidgets('renders actions', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Leaderboard',
          actions: [Icon(Symbols.filter_list_sharp)],
        ),
      ));

      expect(find.byIcon(Symbols.filter_list_sharp), findsOneWidget);
    });

    testWidgets('uses SliverAppBar', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(title: 'Leaderboard'),
      ));

      expect(find.byType(SliverAppBar), findsOneWidget);
    });
  });

  group('TopAppBar - large', () {
    testWidgets('renders expanded title', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
        ),
      ));

      // Both collapsed (opacity 0) and expanded title are in the tree.
      expect(find.text('Produce Every Block'), findsWidgets);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
          subtitle: 'Technical · Jan 12 - Jan 30',
        ),
      ));

      expect(find.text('Technical · Jan 12 - Jan 30'), findsOneWidget);
    });

    testWidgets('renders image when provided', (tester) async {
      await tester.pumpWidget(wrap(
        TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
          image: Container(color: Colors.blue),
        ),
      ));

      // The image is wrapped in ClipRRect for border radius.
      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('renders back arrow by default', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
        ),
      ));

      expect(find.byIcon(Symbols.arrow_back_sharp), findsOneWidget);
    });

    testWidgets('fires onLeadingTap in large variant', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrap(
        TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
          onLeadingTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
      expect(tapped, isTrue);
    });

    testWidgets('renders actions', (tester) async {
      await tester.pumpWidget(wrap(
        const TopAppBar(
          title: 'Produce Every Block',
          size: TopAppBarSize.large,
          actions: [Icon(Symbols.search_sharp)],
        ),
      ));

      expect(find.byIcon(Symbols.search_sharp), findsOneWidget);
    });
  });

  group('TopAppBar - golden', () {
    testWidgets('small variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeWithExtensions(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const TopAppBar(
                  title: 'Leaderboard',
                  actions: [Icon(Symbols.filter_list_sharp)],
                ),
                const SliverFillRemaining(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(CustomScrollView),
        matchesGoldenFile('goldens/top_app_bar_small.png'),
      );
    });

    testWidgets('large variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeWithExtensions(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                TopAppBar(
                  title: 'Produce Every Block',
                  size: TopAppBarSize.large,
                  subtitle: 'Technical · Jan 12 - Jan 30',
                  image: Container(
                    color: const Color(0xFFE3F2FD),
                    child: const Icon(Symbols.hexagon_sharp),
                  ),
                ),
                const SliverFillRemaining(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await expectLater(
        find.byType(CustomScrollView),
        matchesGoldenFile('goldens/top_app_bar_large.png'),
      );
    });
  });
}
