import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/bottom_nav.dart';
import '../src/dapp_card.dart';
import '../src/dropdown_chip.dart';
import '../src/dropdown_sheet.dart';
import '../src/nav_indicator_shapes.dart';
import '../src/parallax_surface_layout.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
WidgetbookComponent dappsPageComponent() {
  return WidgetbookComponent(
    name: 'dApps',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          return const _DappsPage();
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Sort labels (mirrors dapps_screen.dart)
// ---------------------------------------------------------------------------

const _sortLabels = [
  'Popular',
  'Most users',
  'Most transactions',
  'A \u2192 Z'
];

// ---------------------------------------------------------------------------
// Full dApps page
// ---------------------------------------------------------------------------

class _DappsPage extends StatefulWidget {
  const _DappsPage();

  @override
  State<_DappsPage> createState() => _DappsPageState();
}

class _DappsPageState extends State<_DappsPage> {
  int _navIndex = 1;
  int _sortIndex = 0;
  final _scrollFraction = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _scrollFraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final semantic = theme.extension<AppSemanticColors>()!;

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: 1,
        scrollFractionNotifier: _scrollFraction,
        header: const SizedBox.shrink(),
        surfaceSlivers: [
          // 48px content slot — sort bar
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space24),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: sizing.iconContainerRegular,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('dApps', style: theme.textTheme.titleMedium),
                    DropdownChip(
                      label: _sortLabels[_sortIndex],
                      onTap: () async {
                        final result = await showDropdownSheet(
                          context: context,
                          labels: _sortLabels,
                          title: 'Sort',
                          selectedIndex: _sortIndex,
                        );
                        if (result != null) {
                          setState(() => _sortIndex = result);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mock dApp cards
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: spacing.space24),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (_, __) => SizedBox(height: spacing.space8),
              itemBuilder: (_, index) => _buildMockCard(index),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: spacing.space32)),
        ],
      ),
      bottomNavigationBar: BottomNav(
        items: [
          BottomNavItem(
            icon: Symbols.cards_star_sharp,
            label: 'Challenges',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.action_key_sharp,
            label: 'Apps',
            indicatorShape: NavIndicatorShape.blob,
            indicatorColor: semantic.community.color,
            indicatorFillColor: semantic.community.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.account_balance_wallet_sharp,
            label: 'Wallet',
            indicatorShape: NavIndicatorShape.circle,
            indicatorColor: semantic.flash.color,
            indicatorFillColor: semantic.flash.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.check_circle_sharp,
            label: 'Node',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
          BottomNavItem(
            icon: Symbols.settings_sharp,
            label: 'Settings',
            indicatorShape: NavIndicatorShape.hexagon,
            indicatorColor: semantic.technical.color,
            indicatorFillColor: semantic.technical.colorContainer,
          ),
        ],
        selectedIndex: _navIndex,
        onItemSelected: (index) => setState(() => _navIndex = index),
      ),
    );
  }

  DappCard _buildMockCard(int index) {
    const mocks = [
      (
        'Usernode DEX',
        'DeFi Labs',
        'Decentralized exchange for token swaps.',
        842,
        3210
      ),
      (
        'NFT Marketplace',
        'Creative DAO',
        'Mint, buy, and sell NFTs on-chain.',
        215,
        987
      ),
      (
        'Staking Hub',
        'Stake Protocol',
        'Delegate tokens and earn staking rewards.',
        1024,
        5432
      ),
      (
        'Bridge',
        'Cross-Chain Co.',
        'Bridge assets between networks.',
        134,
        412
      ),
    ];
    final (name, author, desc, users, txns) = mocks[index];
    return DappCard(
      name: name,
      author: author,
      description: desc,
      users: users,
      txns: txns,
    );
  }
}

