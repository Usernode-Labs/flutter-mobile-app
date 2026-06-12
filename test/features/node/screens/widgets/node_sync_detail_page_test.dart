import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/node/screens/widgets/node_sync_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  Widget buildApp(Widget child) {
    final textTheme = ThemeData.light().textTheme;
    final cieTheme = ColorIsExpensiveTheme(textTheme);
    final themeData = cieTheme.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        );

    return MaterialApp(theme: themeData, home: child);
  }

  NodeSyncDetailPage buildPage({
    VoidCallback? onBackTap,
    VoidCallback? onSettingsTap,
    VoidCallback? onCopyChainTap,
    VoidCallback? onPeersTap,
  }) {
    return NodeSyncDetailPage(
      title: 'Node Status',
      overview: const NodeSyncOverviewData(
        statusLabel: 'Syncing',
        tone: NodeSyncTone.syncing,
        chainLabel: 'Testnet · Chain 1',
        lastCheckedLabel: 'Last checked at 09:30:18',
        copyChainTooltip: 'Copy chain ID',
      ),
      progress: const NodeSyncProgressData(
        title: 'Syncing blocks 12,842/17,280',
        percentLabel: '74%',
        progress: 0.74,
        supportingLabel: 'Fetch 100% · Apply 74%',
      ),
      sections: [
        NodeSyncDetailSectionData(
          title: 'Network',
          rows: [
            NodeSyncDetailRowData(
              icon: Symbols.hub_sharp,
              title: 'Peers',
              subtitle: '8 of 12 connected',
              trailing: const NodeSyncValueTrailing(
                text: '8',
                showChevron: true,
              ),
              onTap: onPeersTap,
            ),
          ],
        ),
        const NodeSyncDetailSectionData(
          title: 'Chain state',
          rows: [
            NodeSyncDetailRowData(
              icon: Symbols.casino_sharp,
              title: 'VRF',
              subtitle: 'Evaluated 12,842 of 17,280 slots',
              trailing: NodeSyncStatusTrailing(
                text: 'Evaluating',
                variant: StatusBadgeVariant.info,
              ),
            ),
          ],
        ),
      ],
      onBackTap: onBackTap,
      onSettingsTap: onSettingsTap,
      onCopyChainTap: onCopyChainTap,
    );
  }

  testWidgets('renders node sync detail content', (tester) async {
    await tester.pumpWidget(buildApp(buildPage()));

    expect(find.text('Node Status'), findsOneWidget);
    expect(find.text('Syncing'), findsOneWidget);
    expect(find.text('Testnet · Chain 1'), findsOneWidget);
    expect(find.text('Syncing blocks 12,842/17,280'), findsOneWidget);
    expect(find.text('74%'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Peers'), findsOneWidget);
    expect(find.text('Chain state'), findsOneWidget);
    expect(find.text('VRF'), findsOneWidget);
  });

  testWidgets('forwards app bar and row callbacks', (tester) async {
    var backTapped = false;
    var settingsTapped = false;
    var copyTapped = false;
    var peersTapped = false;

    await tester.pumpWidget(
      buildApp(
        buildPage(
          onBackTap: () => backTapped = true,
          onSettingsTap: () => settingsTapped = true,
          onCopyChainTap: () => copyTapped = true,
          onPeersTap: () => peersTapped = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
    await tester.tap(find.byIcon(Symbols.settings_sharp));
    await tester.tap(find.byIcon(Symbols.content_copy_sharp));
    await tester.tap(find.text('Peers'));

    expect(backTapped, isTrue);
    expect(settingsTapped, isTrue);
    expect(copyTapped, isTrue);
    expect(peersTapped, isTrue);
  });

  testWidgets('aligns section row badges with section titles', (tester) async {
    await tester.pumpWidget(buildApp(buildPage()));

    final headerLeft = tester.getTopLeft(find.text('Network')).dx;
    final rowBadge = find.ancestor(
      of: find.byIcon(Symbols.hub_sharp),
      matching: find.byType(IconBadge),
    );
    final badgeLeft = tester.getTopLeft(rowBadge).dx;

    expect((badgeLeft - headerLeft).abs(), lessThan(0.1));
  });
}
