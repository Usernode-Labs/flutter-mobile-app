import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'dapps_app_bar_prototype.stories.g.dart';

const meta = Meta<DappsAppBarPrototype>(path: 'prototypes/apps');

final $Default = _Story(
  name: 'Top app bar shell',
  args: _Args(
    appBarSize: EnumArg(
      TopStatusAppBarSize.large,
      values: TopStatusAppBarSize.values,
    ),
    nodeStatus: EnumArg(
      TopStatusNodeStatus.synced,
      values: TopStatusNodeStatus.values,
    ),
    profileLabel: StringArg('25k pts'),
  ),
  setup: _phoneSetup,
  scenarios: [_Scenario(name: 'Large shell')],
);

/// Stateless Widgetbook-only prototype for aligning the dApps root with the
/// new top status app bar pattern.
class DappsAppBarPrototype extends StatelessWidget {
  const DappsAppBarPrototype({
    super.key,
    this.appBarSize = TopStatusAppBarSize.large,
    this.nodeStatus = TopStatusNodeStatus.synced,
    this.profileLabel = '25k pts',
  });

  final TopStatusAppBarSize appBarSize;
  final TopStatusNodeStatus nodeStatus;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLow,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          switch (appBarSize) {
            TopStatusAppBarSize.large => TopStatusAppBar.large(
              title: 'Apps',
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
            TopStatusAppBarSize.compact => TopStatusAppBar.compact(
              title: 'Apps',
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
            TopStatusAppBarSize.scaffoldCompact => TopStatusAppBar.compact(
              title: 'Apps',
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
          },
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              spacing.space16,
              0,
              spacing.space16,
              spacing.space32,
            ),
            sliver: const SliverToBoxAdapter(child: _DappsDirectoryContent()),
          ),
        ],
      ),
      bottomNavigationBar: const _AppsBottomNav(),
    );
  }
}

class _DappsDirectoryContent extends StatelessWidget {
  const _DappsDirectoryContent();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space12,
      children: [
        const Align(
          alignment: Alignment.centerRight,
          child: DropdownChip(label: 'Popular', onTap: _noop),
        ),
        for (final dapp in _mockDapps)
          DappCard(
            name: dapp.name,
            author: dapp.author,
            description: dapp.description,
            users: dapp.users,
            txns: dapp.txns,
            enabled: dapp.enabled,
            disabledLabel: dapp.disabledLabel,
            onTap: _noop,
          ),
      ],
    );
  }
}

class _AppsBottomNav extends StatelessWidget {
  const _AppsBottomNav();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BottomNav(
      selectedIndex: 1,
      onItemSelected: (_) {},
      items: [
        const BottomNavItem(
          icon: Symbols.cards_star_sharp,
          label: 'Challenges',
          indicatorShape: NavIndicatorShape.circle,
        ),
        BottomNavItem(
          icon: Symbols.action_key_sharp,
          label: 'Apps',
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: colors.onSurface,
          indicatorFillColor: colors.secondaryContainer,
        ),
        const BottomNavItem(
          icon: Symbols.account_balance_wallet_sharp,
          label: 'Wallet',
          indicatorShape: NavIndicatorShape.circle,
        ),
        const BottomNavItem(
          icon: Symbols.receipt_long_sharp,
          label: 'Activity',
          indicatorShape: NavIndicatorShape.circle,
        ),
      ],
    );
  }
}

class _MockDapp {
  const _MockDapp({
    required this.name,
    required this.author,
    required this.description,
    this.users,
    this.txns,
    this.enabled = true,
    this.disabledLabel,
  });

  final String name;
  final String author;
  final String description;
  final int? users;
  final int? txns;
  final bool enabled;
  final String? disabledLabel;
}

const _mockDapps = [
  _MockDapp(
    name: 'Opinion Market',
    author: 'Usernode Labs',
    description:
        'Signal what the network should build next with private votes.',
    users: 1250,
    txns: 48000,
  ),
  _MockDapp(
    name: 'Social Vibecoding',
    author: 'Community',
    description:
        'Prototype, discuss, and ship tiny network-native apps with other builders.',
    users: 920,
    txns: 18300,
  ),
  _MockDapp(
    name: 'Block Explorer',
    author: 'Staketab',
    description: 'Explore blocks, transactions, and account activity.',
    users: 740,
    txns: 112000,
  ),
  _MockDapp(
    name: 'Mini Grants',
    author: 'Ecosystem',
    description: 'Apply for small grants and track community funding rounds.',
    enabled: false,
    disabledLabel: 'Coming Soon',
  ),
];

void _noop() {}

Widget _phoneSetup(
  BuildContext context,
  Widget child,
  DappsAppBarPrototypeArgs args,
) {
  return SizedBox(width: 390, height: 844, child: child);
}
