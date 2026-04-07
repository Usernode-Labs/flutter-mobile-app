@Tags(['golden'])
library;

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'helpers/ds_test_helpers.dart';

void main() {
  group('TopAppBar - golden', () {
    testWidgets('small variant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeWithExtensions(),
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                TopAppBar(
                  title: 'Leaderboard',
                  actions: [Icon(Symbols.filter_list_sharp)],
                ),
                SliverFillRemaining(child: SizedBox()),
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
          home: const Scaffold(
            body: CustomScrollView(
              slivers: [
                TopAppBar(
                  title: 'Produce Every Block',
                  size: TopAppBarSize.large,
                  subtitle: 'Technical · Jan 12 - Jan 30',
                  image: ColoredBox(
                    color: Color(0xFFE3F2FD),
                    child: Icon(Symbols.hexagon_sharp),
                  ),
                ),
                SliverFillRemaining(child: SizedBox()),
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
