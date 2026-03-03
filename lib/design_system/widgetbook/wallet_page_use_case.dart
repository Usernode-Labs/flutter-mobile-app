import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/features/wallet/screens/wallet_delegates.dart';

import '../src/bottom_nav.dart';
import '../src/button.dart';
import '../src/empty_state.dart';
import '../src/full_page_error_state.dart';
import '../src/icon_badge.dart';
import '../src/shimmer_block.dart';
import '../src/shimmer_list_tile.dart';
import '../src/nav_indicator_shapes.dart';
import '../src/parallax_surface_layout.dart';
import '../src/status_badge.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent walletPageComponent() {
  return WidgetbookComponent(
    name: 'Wallet',
    useCases: [
      _playground(),
      _transactionTiles(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Use case 1 — Full page playground with knobs
// ---------------------------------------------------------------------------

enum _DataState { loaded, empty, loading, error }

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final dataState = context.knobs.object.dropdown<_DataState>(
        label: 'Data state',
        options: _DataState.values,
        initialOption: _DataState.loaded,
        labelBuilder: (s) => s.name,
      );
      final isSyncing = context.knobs.boolean(
        label: 'Syncing',
        initialValue: false,
      );
      final hasPending = context.knobs.boolean(
        label: 'Has pending transaction',
        initialValue: true,
      );
      final showCachedBanner = context.knobs.boolean(
        label: 'Cached data banner',
        initialValue: false,
      );
      return _WalletPage(
        dataState: dataState,
        isSyncing: isSyncing,
        hasPending: hasPending,
        showCachedBanner: showCachedBanner,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Use case 2 — Transaction tile variants gallery
// ---------------------------------------------------------------------------

WidgetbookUseCase _transactionTiles() {
  return WidgetbookUseCase(
    name: 'Transaction Tiles',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      Widget label(String text) => Padding(
            padding: EdgeInsets.only(
              top: spacing.space16,
              bottom: spacing.space8,
              left: spacing.space16,
            ),
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );

      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            label('RECEIVED'),
            _buildMockTile(
              context,
              icon: Symbols.south_west_sharp,
              title: 'Received',
              details: 'From: 0x1a2b3c...f4e5d6',
              timestamp: '2026-03-01 14:32:45',
              amount: '+1,000 TOKEN',
              isPending: false,
            ),
            label('SENT'),
            _buildMockTile(
              context,
              icon: Symbols.north_east_sharp,
              title: 'Sent',
              details: 'To: 0x9f8e7d...a1b2c3',
              timestamp: '2026-03-01 12:15:30',
              amount: '-500 TOKEN',
              isPending: false,
            ),
            label('SENT \u2014 PENDING'),
            _buildMockTile(
              context,
              icon: Symbols.hourglass_empty_sharp,
              title: 'Sent',
              details: 'To: 0x9f8e7d...a1b2c3',
              timestamp: '2026-03-03 09:00:12',
              amount: '-250 TOKEN',
              isPending: true,
            ),
            label('BLOCK REWARD'),
            _buildMockTile(
              context,
              icon: Symbols.layers_sharp,
              title: 'Block Reward',
              details: 'Block 1,234,567',
              timestamp: '2026-03-01 10:05:00',
              amount: '+50 TOKEN',
              isPending: false,
            ),
            label('GENESIS ALLOCATION'),
            _buildMockTile(
              context,
              icon: Symbols.diamond_sharp,
              title: 'Genesis Allocation',
              details: '0xgenesis...00000001',
              timestamp: '2025-01-01 00:00:00',
              amount: '+10,000 TOKEN',
              isPending: false,
            ),
            label('FEE'),
            _buildMockTile(
              context,
              icon: Symbols.payment_sharp,
              title: 'Fee',
              details: '0xfee123...abc45678',
              timestamp: '2026-03-01 12:15:30',
              amount: '-1 TOKEN',
              isPending: false,
            ),
            SizedBox(height: spacing.space32),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Constants & mock data
// ---------------------------------------------------------------------------

const _kMockAddress = '0x1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b';

// ---------------------------------------------------------------------------
// Full wallet page
// ---------------------------------------------------------------------------

class _WalletPage extends StatefulWidget {
  const _WalletPage({
    required this.dataState,
    required this.isSyncing,
    required this.hasPending,
    required this.showCachedBanner,
  });

  final _DataState dataState;
  final bool isSyncing;
  final bool hasPending;
  final bool showCachedBanner;

  @override
  State<_WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<_WalletPage> {
  int _navIndex = 2;
  final _scrollFraction = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _scrollFraction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final isEmpty = widget.dataState == _DataState.empty;

    final safeTop = MediaQuery.of(context).padding.top;
    final pinnedHeight = AddressBarDelegate.computeHeight(safeTop, spacing);

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        scrollFractionNotifier: _scrollFraction,
        surfaceFillsViewport: isEmpty,
        pinnedHeaderHeight: pinnedHeight,
        pinnedHeaderSliver: SliverPersistentHeader(
          pinned: true,
          delegate: AddressBarDelegate(
            topPadding: safeTop,
            spacing: spacing,
            scrollFractionNotifier: _scrollFraction,
            address: _kMockAddress,
            onCopy: () {
              Clipboard.setData(const ClipboardData(text: _kMockAddress));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied to clipboard')),
              );
            },
          ),
        ),
        header: Padding(
          padding: EdgeInsets.only(top: spacing.space32),
          child: _buildBalanceSection(context),
        ),
        surfaceBody: isEmpty
            ? EmptyState(
                title: 'No recent activity',
                subtitle: 'Your transactions will appear here',
                action: Button(
                  variant: ButtonVariant.primary,
                  label: 'Send Transaction',
                  onTap: () {},
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      spacing.space16,
                      spacing.space16,
                      spacing.space16,
                      spacing.space8,
                    ),
                    child: Text(
                      'Recent Activity',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (widget.showCachedBanner &&
                      widget.dataState == _DataState.loaded)
                    _buildCachedBanner(context),
                  _buildContent(context),
                  SizedBox(height: spacing.space32),
                ],
              ),
      ),
      floatingActionButton: isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () {},
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              icon: const Icon(Symbols.north_east_sharp),
              label: const Text('Send'),
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

  // -- Balance section -------------------------------------------------------

  Widget _buildBalanceSection(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final isLoading = widget.dataState == _DataState.loading;
    final isError = widget.dataState == _DataState.error;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$TOKEN Balance',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.space4),
        SizedBox(height: spacing.space16),
        if (isLoading)
          const ShimmerBlock(width: 180, height: 36)
        else if (isError)
          Text('\u2014', style: theme.textTheme.displaySmall)
        else
          Text('1,234,567', style: theme.textTheme.displaySmall),
        if (widget.isSyncing)
          Padding(
            padding: EdgeInsets.only(top: spacing.space8),
            child: Text(
              'Sync in progress...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!isLoading && !isError)
          Padding(
            padding: EdgeInsets.only(top: spacing.space4),
            child: Text(
              'Last checked at 14:32:45',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  // -- Cached data banner ----------------------------------------------------

  Widget _buildCachedBanner(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.space16),
      child: Container(
        margin: EdgeInsets.only(bottom: spacing.space8),
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space12,
          vertical: spacing.space8,
        ),
        decoration: BoxDecoration(
          color: semantic.warning.colorContainer,
          borderRadius: radii.borderRadiusSmall,
          border: Border.all(
            color: semantic.warning.color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.warning_amber_sharp,
              color: semantic.warning.color,
              size: sizing.iconXSmall,
            ),
            SizedBox(width: spacing.space8),
            Expanded(
              child: Text(
                'Explorer API unavailable. Showing cached data.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: semantic.warning.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Transaction content ---------------------------------------------------

  Widget _buildContent(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    switch (widget.dataState) {
      case _DataState.loading:
        return Column(
          children: List.generate(4, (_) => const ShimmerListTile()),
        );
      case _DataState.error:
        return const FullPageErrorState(
          message: 'Error loading transactions',
        );
      case _DataState.empty:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.space48),
          child: const EmptyState(
            icon: Symbols.receipt_long_sharp,
            title: 'No recent activity',
            subtitle: 'Your transactions will appear here',
          ),
        );
      case _DataState.loaded:
        return _buildTransactionList(context);
    }
  }

  Widget _buildTransactionList(BuildContext context) {
    final tiles = <Widget>[];

    // Pending send (conditional)
    if (widget.hasPending) {
      tiles.add(_buildMockTile(
        context,
        icon: Symbols.hourglass_empty_sharp,
        title: 'Sent',
        details: 'To: 0x9f8e7d...a1b2c3',
        timestamp: '2026-03-03 09:00:12',
        amount: '-250 TOKEN',
        isPending: true,
      ));
    }

    // Completed transactions
    tiles.addAll([
      _buildMockTile(
        context,
        icon: Symbols.south_west_sharp,
        title: 'Received',
        details: 'From: 0x1a2b3c...f4e5d6',
        timestamp: '2026-03-01 14:32:45',
        amount: '+1,000 TOKEN',
        isPending: false,
      ),
      _buildMockTile(
        context,
        icon: Symbols.north_east_sharp,
        title: 'Sent',
        details: 'To: 0xabcdef...123456',
        timestamp: '2026-02-28 18:20:10',
        amount: '-500 TOKEN',
        isPending: false,
      ),
      _buildMockTile(
        context,
        icon: Symbols.layers_sharp,
        title: 'Block Reward',
        details: 'Block 1,234,567',
        timestamp: '2026-02-28 10:05:00',
        amount: '+50 TOKEN',
        isPending: false,
      ),
      _buildMockTile(
        context,
        icon: Symbols.south_west_sharp,
        title: 'Received',
        details: 'From: 0x5d6e7f...8a9b0c',
        timestamp: '2026-02-27 22:14:33',
        amount: '+2,500 TOKEN',
        isPending: false,
      ),
    ]);

    return Column(
      children: tiles,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared mock tile builder
// ---------------------------------------------------------------------------

Widget _buildMockTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String details,
  required String timestamp,
  required String amount,
  required bool isPending,
}) {
  final theme = Theme.of(context);
  final spacing = Theme.of(context).extension<AppSpacing>()!;
  final colorScheme = theme.colorScheme;
  final semantic = Theme.of(context).extension<AppSemanticColors>()!;

  return ListTile(
    leading: IconBadge(
      icon: icon,
      backgroundColor: isPending
          ? semantic.warning.colorContainer
          : colorScheme.secondaryContainer,
      iconColor: isPending
          ? semantic.warning.onColorContainer
          : colorScheme.onSecondaryContainer,
    ),
    title: Text(title),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(timestamp),
      ],
    ),
    isThreeLine: true,
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount, style: theme.textTheme.bodyMedium),
        if (isPending) ...[
          SizedBox(height: spacing.space4),
          const StatusBadge(
            label: 'Pending',
            variant: StatusBadgeVariant.warning,
          ),
        ],
      ],
    ),
  );
}
