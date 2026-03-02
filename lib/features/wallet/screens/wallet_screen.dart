import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/services/explorer_service.dart';
import 'package:crypto_mobile_app/features/wallet/models/transaction_model.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startAutoRefresh();
  }

  void _loadInitialData() {
    _walletState = ref.read(walletProvider);
    _nodeStatus = ref.read(nodeStatusProvider);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      // Only refresh if currently on wallet tab (index 1)
      final currentTab = ref.read(currentHomeTabProvider);
      if (currentTab == 1) {
        await ref.read(walletProvider.notifier).silentRefresh();
        await ref.read(nodeStatusProvider.notifier).silentRefresh();

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

    // Update local state with fresh data
    setState(() {
      _walletState = ref.read(walletProvider);
      _nodeStatus = ref.read(nodeStatusProvider);
    });

    _startAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final walletState = _walletState;
    final nodeStatus = _nodeStatus;
    final currentTab = ref.watch(currentHomeTabProvider);

    _log.debug('WalletScreen build() called, current tab: $currentTab');

    // Listen for tab changes to refresh when wallet tab becomes active
    ref.listen<int>(currentHomeTabProvider, (previous, next) {
      _log.debug('Tab changed from $previous to $next');
      // Refresh wallet data when switching to wallet tab (index 1)
      if (next == 1 && previous != 1) {
        _log.debug('Switching to wallet tab - triggering refresh');
        _onRefresh();
      }
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(spacing.space16)
                      .copyWith(top: spacing.space24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BalanceSection(
                        walletState: walletState,
                        nodeStatus: nodeStatus,
                        l10n: l10n,
                      ),
                      _AddressCard(theme: theme),
                      const SizedBox(height: 2),
                      _RecentActivityCard(
                        walletState: walletState,
                        l10n: l10n,
                      ),
                      SizedBox(height: spacing.space32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.walletSend),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        icon: const Icon(Icons.north_east),
        label: const Text('Send'),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final syncStatus = nodeStatus.valueOrNull?.syncStatus;
    final showSyncMessage = syncStatus == null || !syncStatus.isSynced;

    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$TOKEN Balance',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.space24),
            walletState.when(
              data: (state) => Text(
                state.balance.getFormattedBalance(compact: false, decimals: 0),
                style: theme.textTheme.displaySmall,
              ),
              loading: () => const SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              error: (_, __) => Text(
                l10n.commonNoValuePlaceholder,
                style: theme.textTheme.displaySmall,
              ),
            ),
            if (showSyncMessage && nodeStatus.hasValue)
              Padding(
                padding: EdgeInsets.only(top: spacing.space8),
                child: Text(
                  'Sync in progress...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
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
                        fontSize: 11,
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
        ),
      ),
    );
  }
}

class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceBright,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(spacing.space24),
      child: ref.watch(accountsProvider).when(
            data: (repo) => FutureBuilder(
              future: repo.getActive(),
              builder: (context, snapshot) {
                final address = snapshot.data?.address ?? 'Loading...';
                return _AddressRow(address: address, theme: theme);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Error loading address')),
          ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.theme});

  final String address;
  final ThemeData theme;

  String get _displayAddress => address.length > 16
      ? '${address.substring(0, 8)}...${address.substring(address.length - 8)}'
      : address;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.tag, color: theme.colorScheme.onSurface),
        ),
        SizedBox(width: spacing.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Address',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: spacing.space4),
              Text(
                _displayAddress,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.space12),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address copied to clipboard')),
            );
          },
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
                horizontal: spacing.space16, vertical: spacing.space8),
          ),
          child: const Text('Copy'),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.walletState, required this.l10n});

  final AsyncValue walletState;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceBright,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(spacing.space16)
          .copyWith(top: spacing.space12, bottom: spacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          SizedBox(height: spacing.space16),
          // API status banner for transaction data
          walletState.when(
            data: (state) {
              // Check if we have non-local transactions
              final hasExplorerData =
                  state.recent.any((tx) => tx.dataSource != DataSource.local);
              final hasOnlyCachedData = state.recent.every((tx) =>
                  tx.dataSource == DataSource.cached ||
                  tx.dataSource == DataSource.local);

              if (hasExplorerData &&
                  hasOnlyCachedData &&
                  state.recent.isNotEmpty) {
                return Container(
                  margin: EdgeInsets.only(bottom: spacing.space8),
                  padding: EdgeInsets.symmetric(
                      horizontal: spacing.space12, vertical: spacing.space8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade700, size: 16),
                      SizedBox(width: spacing.space8),
                      Expanded(
                        child: Text(
                          'Explorer API unavailable. Showing cached data.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          walletState.when(
            data: (state) => state.recent.isEmpty
                ? _EmptyState(message: l10n.walletNoRecentActivity)
                : Column(
                    children: state.recent
                        .map<Widget>(
                            (transaction) => _TransactionTile(transaction))
                        .toList()),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Error loading transactions')),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: spacing.space48, horizontal: spacing.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          SizedBox(height: spacing.space16),
          Text(
            l10n.walletNoRecentActivity,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: spacing.space8),
          Text(
            l10n.walletNoRecentActivitySubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPending = transaction.status == TransactionStatus.pending;

    // Determine container color based on transaction type
    Color containerColor;
    if (transaction.type == TransactionType.reward ||
        transaction.type == TransactionType.genesis) {
      containerColor = Colors.orange.withValues(alpha: 0.2);
    } else {
      // Use secondaryContainer for all other types (send, receive, pending)
      containerColor = colorScheme.secondaryContainer;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: spacing.space8, horizontal: spacing.space8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Center(
                  child: isPending && transaction.type == TransactionType.send
                      ? Icon(Icons.hourglass_empty,
                          color: colorScheme.onSurface, size: 20)
                      : Icon(transaction.icon,
                          color: colorScheme.onSurface, size: 20),
                ),
                if (isPending)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: colorScheme.surface, width: 1),
                      ),
                      child: const Icon(
                        Icons.schedule,
                        color: Colors.white,
                        size: 6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: spacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayDetails(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.formattedTimestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${transaction.formattedAmount} ${transaction.tokenSymbol}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
