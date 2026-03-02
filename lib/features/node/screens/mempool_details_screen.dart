import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';

class MempoolDetailsScreen extends ConsumerStatefulWidget {
  const MempoolDetailsScreen({super.key});

  @override
  ConsumerState<MempoolDetailsScreen> createState() =>
      _MempoolDetailsScreenState();
}

class _MempoolDetailsScreenState extends ConsumerState<MempoolDetailsScreen> {
  Timer? _autoTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_refreshing) {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(nodeMempoolProvider.notifier).refresh();
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final mempoolAsync = ref.watch(nodeMempoolProvider);

    return Scaffold(
      appBar: AppAppBar(
        title: l10n.mempoolTitle,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: mempoolAsync.when(
          loading: () => const FullPageLoadingState(),
          error: (error, stack) => FullPageErrorState(
            message: l10n.mempoolLoadFailed,
            detail: error.toString(),
            onRetry: _refresh,
            retryLabel: l10n.mempoolRetry,
          ),
          data: (mempool) {
            if (mempool == null || mempool.entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Symbols.inbox_sharp,
                      size: 64,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    SizedBox(height: spacing.space16),
                    Text(
                      l10n.mempoolNoTransactions,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.space8),
                    Text(
                      l10n.mempoolEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                // Summary header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(spacing.space16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        'Total',
                        mempool.count.toString(),
                        Symbols.receipt_long_sharp,
                        colorScheme.primary,
                      ),
                      _buildStatColumn(
                        context,
                        'Orphans',
                        mempool.orphans.toString(),
                        Symbols.warning_amber_sharp,
                        Theme.of(context)
                            .extension<AppSemanticColors>()!
                            .warning
                            .color,
                      ),
                      _buildStatColumn(
                        context,
                        'Size',
                        _formatBytes(mempool.totalSize),
                        Symbols.data_usage_sharp,
                        colorScheme.secondary,
                      ),
                    ],
                  ),
                ),

                // Transaction list
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        spacing.space16, 0, spacing.space16, spacing.space32),
                    itemCount: mempool.entries.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final tx = mempool.entries[index];
                      return _buildTransactionListItem(
                        context,
                        tx,
                        colorScheme,
                        theme,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        SizedBox(height: spacing.space4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionListItem(
    BuildContext context,
    MempoolTxSummary tx,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final txHash = _formatTxHash(tx.id.toString());
    final fee = tx.fee.toString();

    // Optional: Add priority indicator emoji based on fee amount
    String feeDisplay = fee;
    if (tx.fee > BigInt.from(400)) {
      feeDisplay = '$fee ⚡';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        radius: 16,
        child: Icon(
          Symbols.receipt_long_sharp,
          size: 14,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        txHash,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: spacing.space4),
        child: Text(
          'Fee: $feeDisplay  •  In: ${tx.inputs.length}  Out: ${tx.outputs.length}  •  ${tx.sizeBytes}B',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: TextButton(
        onPressed: () => _showComingSoonModal(context),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
              horizontal: spacing.space8, vertical: spacing.space4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: spacing.space4),
            Icon(
              Symbols.arrow_forward_sharp,
              size: 12,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoonModal(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Symbols.schedule_sharp,
            size: 48,
            color: colorScheme.primary,
          ),
          title: Text(
            'Coming Soon',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Transaction details will be available in a future update.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _formatTxHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 8)}';
  }

  String _formatBytes(BigInt bytes) {
    final b = bytes.toInt();
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
