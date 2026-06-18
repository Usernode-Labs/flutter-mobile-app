import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

void main() {
  Widget wrap(Widget sliver, {ScrollController? controller}) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        body: CustomScrollView(
          controller: controller,
          slivers: [
            sliver,
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 1000,
                child: Center(child: Text('Content')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget wrapScaffold(PreferredSizeWidget appBar) {
    return MaterialApp(
      theme: themeWithExtensions(),
      home: Scaffold(
        appBar: appBar,
        body: const Center(child: Text('Content')),
      ),
    );
  }

  const surfaceKey = ValueKey('top_status_app_bar_surface');
  const bottomBorderKey = ValueKey('top_status_app_bar_bottom_border');
  const profileHitKey = ValueKey('top_status_profile_action_hit');
  const profileVisualKey = ValueKey('top_status_profile_action_visual');
  const profileIconKey = ValueKey('top_status_profile_action_icon');
  const profileLabelOpacityKey =
      ValueKey('top_status_profile_action_label_opacity');
  const nodeHitKey = ValueKey('top_status_node_action_hit');
  const nodeVisualKey = ValueKey('top_status_node_action_visual');
  const nodeIconKey = ValueKey('top_status_node_action_icon');
  const nodeLabelOpacityKey = ValueKey('top_status_node_action_label_opacity');

  testWidgets('large variant renders M3 large app bar with 40dp status pills', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const TopStatusAppBar.large(
          title: 'Season 1',
          profileLabel: '25k pts',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: null,
          onNodePressed: null,
        ),
      ),
    );

    expect(find.byType(SliverPersistentHeader), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('Season 1'), findsWidgets);
    expect(find.text('25k pts'), findsOneWidget);
    expect(find.text('Synced'), findsOneWidget);
    expect(find.byIcon(Symbols.account_circle_sharp), findsOneWidget);
    expect(find.byIcon(Symbols.check_sharp), findsOneWidget);

    final profileVisual = tester.getRect(find.byKey(profileVisualKey));
    final nodeVisual = tester.getRect(find.byKey(nodeVisualKey));
    final profileHit = tester.getSize(find.byKey(profileHitKey));
    final nodeHit = tester.getSize(find.byKey(nodeHitKey));
    final scrollWidth = tester.getSize(find.byType(CustomScrollView)).width;
    final surface = tester.widget<ColoredBox>(find.byKey(surfaceKey));
    final border = tester.widget<ColoredBox>(find.byKey(bottomBorderKey));
    final profileIcon = tester.widget<Icon>(find.byKey(profileIconKey));
    final nodeIcon = tester.widget<Icon>(find.byKey(nodeIconKey));

    expect(surface.color, equals(Colors.transparent));
    expect(border.color, equals(Colors.transparent));
    expect(profileVisual.height, equals(40));
    expect(nodeVisual.height, equals(40));
    expect(profileVisual.width, greaterThan(64));
    expect(nodeVisual.width, greaterThan(64));
    expect(profileHit.height, greaterThanOrEqualTo(48));
    expect(nodeHit.height, greaterThanOrEqualTo(48));
    expect(profileVisual.left, closeTo(16, 0.1));
    expect(scrollWidth - nodeVisual.right, closeTo(16, 0.1));
    expect(profileIcon.size, equals(20));
    expect(nodeIcon.size, equals(20));
  });

  testWidgets('compact variant renders icon-only status actions',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const TopStatusAppBar.compact(
          title: 'Season 1',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: null,
          onNodePressed: null,
        ),
      ),
    );

    expect(find.text('Season 1'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    expect(find.byIcon(Symbols.account_circle_sharp), findsOneWidget);
    expect(find.byIcon(Symbols.check_sharp), findsOneWidget);

    final surfaceColor = Theme.of(
      tester.element(find.byType(CustomScrollView)),
    ).colorScheme.surfaceContainerLowest;
    final colors =
        Theme.of(tester.element(find.byType(CustomScrollView))).colorScheme;
    final borders = Theme.of(tester.element(find.byType(CustomScrollView)))
        .extension<AppBorders>()!;
    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    final shape = appBar.shape as Border;

    expect(appBar.backgroundColor, equals(surfaceColor));
    expect(
      shape.bottom.color,
      equals(colors.onSurface.withValues(alpha: borders.opacity)),
    );
    expect(shape.bottom.width, equals(borders.width));
    expect(tester.getSize(find.byKey(profileVisualKey)),
        equals(const Size(40, 40)));
    expect(
        tester.getSize(find.byKey(nodeVisualKey)), equals(const Size(40, 40)));
    expect(tester.widget<Icon>(find.byKey(profileIconKey)).size, equals(24));
    expect(tester.widget<Icon>(find.byKey(nodeIconKey)).size, equals(24));
  });

  testWidgets('scaffold compact variant fits a Scaffold appBar slot', (
    tester,
  ) async {
    var profileTapped = false;
    var nodeTapped = false;

    await tester.pumpWidget(
      wrapScaffold(
        TopStatusAppBar.scaffoldCompact(
          title: 'dApps',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: () => profileTapped = true,
          onNodePressed: () => nodeTapped = true,
        ),
      ),
    );

    expect(find.byType(TopStatusAppBar), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(SliverAppBar), findsNothing);
    expect(find.text('dApps'), findsOneWidget);
    expect(find.text('Synced'), findsNothing);
    expect(find.byIcon(Symbols.account_circle_sharp), findsOneWidget);
    expect(find.byIcon(Symbols.check_sharp), findsOneWidget);

    final surfaceColor = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.surfaceContainerLowest;
    final colors = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    final borders = Theme.of(tester.element(find.byType(Scaffold)))
        .extension<AppBorders>()!;
    final topStatus =
        tester.widget<TopStatusAppBar>(find.byType(TopStatusAppBar));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    final shape = appBar.shape as Border;

    expect(topStatus.preferredSize, equals(const Size.fromHeight(64)));
    expect(appBar.toolbarHeight, equals(64));
    expect(appBar.backgroundColor, equals(surfaceColor));
    expect(
      shape.bottom.color,
      equals(colors.onSurface.withValues(alpha: borders.opacity)),
    );
    expect(shape.bottom.width, equals(borders.width));
    expect(tester.getSize(find.byKey(profileVisualKey)),
        equals(const Size(40, 40)));
    expect(
        tester.getSize(find.byKey(nodeVisualKey)), equals(const Size(40, 40)));

    await tester.tap(find.byKey(profileHitKey));
    await tester.tap(find.byKey(nodeHitKey));

    expect(profileTapped, isTrue);
    expect(nodeTapped, isTrue);
  });

  testWidgets('large variant morphs pills into icon buttons on scroll', (
    tester,
  ) async {
    final controller = ScrollController();

    await tester.pumpWidget(
      wrap(
        const TopStatusAppBar.large(
          title: 'Season 1',
          profileLabel: '25k pts',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: null,
          onNodePressed: null,
        ),
        controller: controller,
      ),
    );

    controller.jumpTo(200);
    await tester.pump();

    final profileVisual = tester.getSize(find.byKey(profileVisualKey));
    final nodeVisual = tester.getSize(find.byKey(nodeVisualKey));
    final profileLabelOpacity =
        tester.widget<Opacity>(find.byKey(profileLabelOpacityKey));
    final nodeLabelOpacity =
        tester.widget<Opacity>(find.byKey(nodeLabelOpacityKey));
    final surface = tester.widget<ColoredBox>(find.byKey(surfaceKey));
    final surfaceColor = Theme.of(
      tester.element(find.byType(CustomScrollView)),
    ).colorScheme.surfaceContainerLowest;
    final colors =
        Theme.of(tester.element(find.byType(CustomScrollView))).colorScheme;
    final borders = Theme.of(tester.element(find.byType(CustomScrollView)))
        .extension<AppBorders>()!;
    final border = tester.widget<ColoredBox>(find.byKey(bottomBorderKey));

    expect(profileVisual, equals(const Size(40, 40)));
    expect(nodeVisual, equals(const Size(40, 40)));
    expect(tester.widget<Icon>(find.byKey(profileIconKey)).size, equals(24));
    expect(tester.widget<Icon>(find.byKey(nodeIconKey)).size, equals(24));
    expect(profileLabelOpacity.opacity, equals(0));
    expect(nodeLabelOpacity.opacity, equals(0));
    expect(surface.color, equals(surfaceColor));
    expect(
      border.color,
      equals(colors.onSurface.withValues(alpha: borders.opacity)),
    );
  });

  testWidgets('node status resolves canonical labels icons and surfaces', (
    tester,
  ) async {
    Future<void> pumpStatus(TopStatusNodeStatus status) {
      return tester.pumpWidget(
        wrap(
          TopStatusAppBar.large(
            title: 'Season 1',
            nodeStatus: status,
            onProfilePressed: null,
            onNodePressed: () {},
          ),
        ),
      );
    }

    await pumpStatus(TopStatusNodeStatus.synced);

    final context = tester.element(find.byType(TopStatusAppBar));
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final cases = [
      (
        status: TopStatusNodeStatus.synced,
        label: 'Synced',
        icon: Symbols.check_sharp,
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
      ),
      (
        status: TopStatusNodeStatus.connecting,
        label: 'Connecting',
        icon: Symbols.hourglass_empty_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
      (
        status: TopStatusNodeStatus.syncing,
        label: 'Syncing',
        icon: Symbols.hourglass_empty_sharp,
        background: semantic.warning.colorContainer,
        foreground: semantic.warning.onColorContainer,
      ),
      (
        status: TopStatusNodeStatus.offline,
        label: 'Offline',
        icon: Symbols.close_sharp,
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
      ),
    ];

    for (final testCase in cases) {
      await pumpStatus(testCase.status);

      final visual = tester.widget<Material>(find.byKey(nodeVisualKey));
      final icon = tester.widget<Icon>(find.byKey(nodeIconKey));

      expect(find.text(testCase.label), findsOneWidget);
      expect(find.byIcon(testCase.icon), findsOneWidget);
      expect(visual.color, equals(testCase.background));
      expect(icon.color, equals(testCase.foreground));
    }
  });

  testWidgets('status intent keeps synced semantically green', (tester) async {
    await tester.pumpWidget(
      wrap(
        const TopStatusAppBar.large(
          title: 'Season 1',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: null,
          onNodePressed: null,
        ),
      ),
    );

    final context = tester.element(find.byType(TopStatusAppBar));
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final visual = TopStatusNodeVisual.resolve(
      context,
      TopStatusNodeStatus.synced,
    );

    expect(visual.backgroundColor, equals(semantic.success.colorContainer));
    expect(visual.foregroundColor, equals(semantic.success.onColorContainer));
  });

  testWidgets('fires profile and node callbacks in expanded and collapsed bars',
      (
    tester,
  ) async {
    var profileTapped = false;
    var nodeTapped = false;
    final controller = ScrollController();

    await tester.pumpWidget(
      wrap(
        TopStatusAppBar.large(
          title: 'Season 1',
          profileLabel: '25k pts',
          nodeStatus: TopStatusNodeStatus.synced,
          onProfilePressed: () => profileTapped = true,
          onNodePressed: () => nodeTapped = true,
        ),
        controller: controller,
      ),
    );

    await tester.tap(find.byKey(profileHitKey));
    await tester.tap(find.byKey(nodeHitKey));

    expect(profileTapped, isTrue);
    expect(nodeTapped, isTrue);

    profileTapped = false;
    nodeTapped = false;

    controller.jumpTo(200);
    await tester.pump();

    await tester.tap(find.byKey(profileHitKey));
    await tester.tap(find.byKey(nodeHitKey));

    expect(profileTapped, isTrue);
    expect(nodeTapped, isTrue);
  });
}
