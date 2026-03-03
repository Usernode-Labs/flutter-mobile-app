import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_delegates.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

final _log = LoggingService.instance.withTag('usernode/WalletScreen');

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Timer? _refreshTimer;
  late AsyncValue _walletState;
  late AsyncValue _nodeStatus;
  final _scrollFraction = ValueNotifier<double>(0.0);
  String _address = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startAutoRefresh();

    // Resolve address when accounts provider loads or changes.
    ref.listenManual(accountsProvider, (_, __) => _resolveAddress());

    // React to tab changes — refresh when wallet tab becomes active.
    ref.listenManual(currentHomeTabProvider, (previous, next) {
      if (next == 1 && previous != 1) {
        _log.debug('Switching to wallet tab - triggering refresh');
        _onRefresh();
      }
    });
  }

  void _loadInitialData() {
    _walletState = ref.read(walletProvider);
    _nodeStatus = ref.read(nodeStatusProvider);
  }

  Future<void> _resolveAddress() async {
    final accounts = ref.read(accountsProvider);
    final repo = accounts.valueOrNull;
    if (repo == null) return;
    final active = await repo.getActive();
    if (mounted && active != null) {
      setState(() => _address = active.address);
    }
  }

  @override
  void dispose() {
    _scrollFraction.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Only refresh if currently on wallet tab (index 1)
      final currentTab = ref.read(currentHomeTabProvider);
      if (currentTab == 1) {
        await Future.wait([
          ref.read(walletProvider.notifier).silentRefresh(),
          ref.read(nodeStatusProvider.notifier).silentRefresh(),
        ]);

        // Update local state with fresh data
        if (mounted) {
          setState(() {
            _walletState = ref.read(walletProvider);
            _nodeStatus = ref.read(nodeStatusProvider);
          });
        }
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(walletProvider.notifier).silentRefresh(),
      ref.read(nodeStatusProvider.notifier).silentRefresh(),
    ]);

    if (!mounted) return;

    // Update local state with fresh data
    setState(() {
      _walletState = ref.read(walletProvider);
      _nodeStatus = ref.read(nodeStatusProvider);
    });

    _startAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final walletState = _walletState;
    final nodeStatus = _nodeStatus;

    final isEmpty = walletState.valueOrNull?.recent.isEmpty ?? false;

    final safeTop = MediaQuery.of(context).padding.top;
    final pinnedHeight = AddressBarDelegate.computeHeight(safeTop, spacing);

    return Scaffold(
      body: ParallaxSurfaceLayout(
        headerHeight: kScreenHeaderHeight,
        onRefresh: _onRefresh,
        scrollFractionNotifier: _scrollFraction,
        surfaceFillsViewport: isEmpty,
        pinnedHeaderHeight: pinnedHeight,
        pinnedHeaderSliver: SliverPersistentHeader(
          pinned: true,
          delegate: AddressBarDelegate(
            topPadding: safeTop,
            spacing: spacing,
            scrollFractionNotifier: _scrollFraction,
            address: _address,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: _address));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address copied to clipboard')),
              );
            },
          ),
        ),
        header: Padding(
          padding: EdgeInsets.only(top: spacing.space32),
          child: _BalanceSection(
            walletState: walletState,
            nodeStatus: nodeStatus,
            l10n: l10n,
          ),
        ),
        surfaceBody: isEmpty
            ? EmptyState(
                title: l10n.walletNoRecentActivity,
                subtitle: l10n.walletNoRecentActivitySubtitle,
                action: Button(
                  variant: ButtonVariant.primary,
                  label: l10n.walletEmptyStateSendAction,
                  onTap: () => context.push(AppRoutes.walletSend),
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
                  _buildCachedDataBanner(walletState, theme, spacing),
                  _buildTransactionContent(walletState, l10n, spacing),
                  SizedBox(height: spacing.space32),
                ],
              ),
      ),
      floatingActionButton: isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.walletSend),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              icon: const Icon(Symbols.north_east_sharp),
              label: const Text('Send'),
            ),
    );
  }

  Widget _buildCachedDataBanner(
    AsyncValue walletState,
    ThemeData theme,
    AppSpacing spacing,
  ) {
    return walletState.when(
      data: (state) {
        final hasExplorerData =
            state.recent.any((tx) => tx.dataSource != DataSource.local);
        final hasOnlyCachedData = state.recent.every((tx) =>
            tx.dataSource == DataSource.cached ||
            tx.dataSource == DataSource.local);

        if (hasExplorerData && hasOnlyCachedData && state.recent.isNotEmpty) {
          final semantic = theme.extension<AppSemanticColors>()!;
          final sizing = theme.extension<AppSizing>()!;
          final radii = theme.extension<AppRadii>()!;

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
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTransactionContent(
      AsyncValue walletState, AppLocalizations l10n, AppSpacing spacing) {
    return walletState.when(
      data: (state) {
        if (state.recent.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: spacing.space48,
            ),
            child: EmptyState(
              icon: Symbols.receipt_long_sharp,
              title: l10n.walletNoRecentActivity,
              subtitle: l10n.walletNoRecentActivitySubtitle,
            ),
          );
        }
        return Column(
          children: [
            for (final tx in state.recent) _TransactionTile(tx),
          ],
        );
      },
      loading: () => Column(
        children: List.generate(4, (_) => const ShimmerListTile()),
      ),
      error: (_, __) => const FullPageErrorState(
        message: 'Error loading transactions',
      ),
    );
  }
}

// --- Extracted Widgets ---

class _BalanceSection extends StatelessWidget {
  const _BalanceSection({
    required this.walletState,
    required this.nodeStatus,
    required this.l10n,
  });

  final AsyncValue walletState;
  final AsyncValue nodeStatus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final syncStatus = nodeStatus.valueOrNull?.syncStatus;
    final showSyncMessage = syncStatus == null || !syncStatus.isSynced;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$TOKEN Balance',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: spacing.space16),
        walletState.when(
          data: (state) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: state.balance.tokenAmount),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              NumberFormat('#,##0').format(value.toInt()),
              style: theme.textTheme.displaySmall
                  ?.copyWith(fontFamily: 'IBMPlexMono'),
            ),
          ),
          loading: () => const ShimmerBlock(width: 180, height: 36),
          error: (_, __) => Text(
            l10n.commonNoValuePlaceholder,
            style: theme.textTheme.displaySmall
                ?.copyWith(fontFamily: 'IBMPlexMono'),
          ),
        ),
        if (showSyncMessage && nodeStatus.hasValue)
          Padding(
            padding: EdgeInsets.only(top: spacing.space8),
            child: Text(
              'Sync in progress...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        // Data source indicator
        walletState.when(
          data: (state) {
            final balance = state.balance;
            if (balance.lastUpdated != null) {
              return Padding(
                padding: EdgeInsets.only(top: spacing.space4),
                child: Text(
                  'Last checked at ${balance.lastUpdatedText}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);
  final TransactionModel transaction;

  String _shorten(String value) {
    if (value.length <= 16) return value;
    return '${value.substring(0, 8)}...${value.substring(value.length - 8)}';
  }

  String _displayDetails() {
    switch (transaction.type) {
      case TransactionType.send:
        return transaction.subtitle.startsWith('To:')
            ? transaction.subtitle
            : transaction.shortHash;
      case TransactionType.receive:
        return transaction.subtitle.startsWith('From:')
            ? transaction.subtitle
            : transaction.shortHash;
      case TransactionType.reward:
        const prefix = 'reward:';
        final id = transaction.id;
        final normalized =
            id.startsWith(prefix) ? id.substring(prefix.length) : id;
        return _shorten(normalized);
      case TransactionType.genesis:
      case TransactionType.fee:
        return transaction.shortHash;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>()!;
    final isPending = transaction.status == TransactionStatus.pending;

    return ListTile(
      leading: IconBadge(
        icon: isPending && transaction.type == TransactionType.send
            ? Symbols.hourglass_empty_sharp
            : transaction.icon,
        backgroundColor: isPending
            ? semantic.warning.colorContainer
            : colorScheme.secondaryContainer,
        iconColor: isPending
            ? semantic.warning.onColorContainer
            : colorScheme.onSecondaryContainer,
      ),
      title: Text(transaction.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displayDetails(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(transaction.formattedTimestamp),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${transaction.formattedAmount} ${transaction.tokenSymbol}',
            style: theme.textTheme.bodyMedium,
          ),
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
}
