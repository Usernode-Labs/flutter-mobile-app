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

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final syncStatus = ref.read(nodeStatusProvider).valueOrNull?.syncStatus;

      if (syncStatus?.isSynced == true) {
        timer.cancel();
      } else {
        ref.read(walletProvider.notifier).silentRefresh();
        ref.read(nodeStatusProvider.notifier).silentRefresh();
      }
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      ref.read(walletProvider.notifier).refresh(),
      ref.read(nodeStatusProvider.notifier).refresh(),
    ]);
    _startAutoRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final walletState = ref.watch(walletProvider);
    final nodeStatus = ref.watch(nodeStatusProvider);

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
                  padding: const EdgeInsets.all(16).copyWith(top: 24),
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
            const SizedBox(height: 20),
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
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sync in progress...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceBright,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
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
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Address',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _displayAddress,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Address copied to clipboard')),
            );
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceBright,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16).copyWith(top: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile(this.transaction);
  final dynamic transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPending = transaction.status.toString().contains('pending');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(transaction.icon,
                    color: theme.colorScheme.onSurface, size: 20),
              ),
              if (isPending)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: theme.colorScheme.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isPending
                              ? theme.colorScheme.onSurface
                                  .withValues(alpha: 0.8)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (isPending)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'PENDING',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.fullSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isPending
                        ? theme.colorScheme.secondary.withValues(alpha: 0.7)
                        : theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${transaction.formattedAmount} ${transaction.tokenSymbol}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPending
                  ? (transaction.isPositive
                      ? Colors.green.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7))
                  : (transaction.isPositive
                      ? Colors.green
                      : theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
