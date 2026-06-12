import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'wallet_app_bar_prototype.stories.g.dart';

const meta = Meta<WalletAppBarPrototype>(path: 'prototypes/apps');

const _mockAddress = 'ut1q7c9a6f4a2b7e9d1c3f8a4b2e5d9c1a6f0b3e7d4c8a2f';

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
  scenarios: [_Scenario(name: 'Address in body')],
);

/// Widgetbook-only prototype for aligning the wallet root with the new top
/// status app bar pattern.
class WalletAppBarPrototype extends StatelessWidget {
  const WalletAppBarPrototype({
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
              title: 'Wallet',
              profileLabel: profileLabel,
              nodeStatus: nodeStatus,
              onProfilePressed: _noop,
              onNodePressed: _noop,
            ),
            TopStatusAppBarSize.compact => TopStatusAppBar.compact(
              title: 'Wallet',
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
            sliver: const SliverToBoxAdapter(child: _WalletContent()),
          ),
        ],
      ),
      bottomNavigationBar: const _WalletBottomNav(),
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent();

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.space12,
      children: const [_BalanceCard(), _AddressRow(), _RecentActivitySection()],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.space16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.space4,
            children: [
              Text(
                '\$TOKEN Balance',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                '12,840',
                style: textTheme.displaySmall?.copyWith(
                  fontFamily: kMonoFontFamily,
                  color: colors.onSurface,
                ),
              ),
              Text(
                'Last checked at 09:30:18',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Row(
            spacing: spacing.space8,
            children: [
              Expanded(
                child: Button(
                  label: 'Send',
                  variant: ButtonVariant.primary,
                  leadingIcon: const Icon(Symbols.north_east_sharp),
                  onTap: _noop,
                ),
              ),
              Expanded(
                child: Button(
                  label: 'Scan',
                  variant: ButtonVariant.tonal,
                  leadingIcon: const Icon(Symbols.qr_code_scanner_sharp),
                  onTap: _noop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final textTheme = Theme.of(context).textTheme;
    final address = _shortenAddress(_mockAddress);

    return AppCard(
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      child: Row(
        children: [
          IconBadge(
            icon: Symbols.account_balance_wallet_sharp,
            size: sizing.iconContainerSmall,
          ),
          SizedBox(width: spacing.space16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: spacing.space4,
              children: [
                Text(
                  'My address',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onSurface,
                    fontFamily: kMonoFontFamily,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.space8),
          IconButton(
            tooltip: 'Copy address',
            onPressed: _noop,
            icon: const Icon(Symbols.content_copy_sharp),
          ),
          IconButton(
            tooltip: 'Show QR',
            onPressed: _noop,
            icon: const Icon(Symbols.qr_code_2_sharp),
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return AppCard(
      color: colors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(vertical: spacing.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space16,
              vertical: spacing.space8,
            ),
            child: Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in _mockTransactions) _WalletActivityRow(item: item),
        ],
      ),
    );
  }
}

class _WalletActivityRow extends StatelessWidget {
  const _WalletActivityRow({required this.item});

  final _MockWalletActivity item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return ListTile(
      leading: IconBadge(
        icon: item.icon,
        backgroundColor: item.pending
            ? semantic.warning.colorContainer
            : colors.secondaryContainer,
        iconColor: item.pending
            ? semantic.warning.onColorContainer
            : colors.onSecondaryContainer,
      ),
      title: Text(item.title),
      subtitle: Text(
        item.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(item.amount),
          Text(
            item.time,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _WalletBottomNav extends StatelessWidget {
  const _WalletBottomNav();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BottomNav(
      selectedIndex: 2,
      onItemSelected: (_) {},
      items: [
        const BottomNavItem(
          icon: Symbols.cards_star_sharp,
          label: 'Challenges',
          indicatorShape: NavIndicatorShape.circle,
        ),
        const BottomNavItem(
          icon: Symbols.action_key_sharp,
          label: 'Apps',
          indicatorShape: NavIndicatorShape.circle,
        ),
        BottomNavItem(
          icon: Symbols.account_balance_wallet_sharp,
          label: 'Wallet',
          indicatorShape: NavIndicatorShape.circle,
          indicatorColor: colors.onSurface,
          indicatorFillColor: colors.secondaryContainer,
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

class _MockWalletActivity {
  const _MockWalletActivity({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.time,
    required this.icon,
    this.pending = false,
  });

  final String title;
  final String subtitle;
  final String amount;
  final String time;
  final IconData icon;
  final bool pending;
}

const _mockTransactions = [
  _MockWalletActivity(
    title: 'Received',
    subtitle: 'From ut1q7c9a...8a2f',
    amount: '+1,250 TOKEN',
    time: '2m',
    icon: Symbols.south_west_sharp,
  ),
  _MockWalletActivity(
    title: 'Sending · pending',
    subtitle: 'To Opinion Market',
    amount: '-500 TOKEN',
    time: 'now',
    icon: Symbols.hourglass_empty_sharp,
    pending: true,
  ),
  _MockWalletActivity(
    title: 'Reward',
    subtitle: 'Epoch 176 block production',
    amount: '+6,500 TOKEN',
    time: '1h',
    icon: Symbols.workspace_premium_sharp,
  ),
];

String _shortenAddress(String value) {
  if (value.length <= 20) return value;
  return '${value.substring(0, 10)}...${value.substring(value.length - 8)}';
}

void _noop() {}

Widget _phoneSetup(
  BuildContext context,
  Widget child,
  WalletAppBarPrototypeArgs args,
) {
  return SizedBox(width: 390, height: 844, child: child);
}
