import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';

class MempoolDetailsScreen extends ConsumerWidget {
  const MempoolDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mempoolAsync = ref.watch(nodeMempoolProvider);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Mempool Transactions',
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(nodeMempoolProvider.notifier).refresh();
        },
        child: mempoolAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load mempool',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(nodeMempoolProvider.notifier).refresh();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (mempool) {
            if (mempool == null || mempool.entries.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions in mempool',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The mempool is currently empty',
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                        Icons.receipt_long,
                        colorScheme.primary,
                      ),
                      _buildStatColumn(
                        context,
                        'Orphans',
                        mempool.orphans.toString(),
                        Icons.warning_amber_outlined,
                        Colors.orange,
                      ),
                      _buildStatColumn(
                        context,
                        'Size',
                        _formatBytes(mempool.totalSize),
                        Icons.data_usage,
                        colorScheme.secondary,
                      ),
                    ],
                  ),
                ),

                // Transaction list
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
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
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
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
          Icons.receipt_long,
          size: 14,
          color: colorScheme.primary,
        ),
      ),
      title: Text(
        txHash,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          'Fee: $feeDisplay  •  In: ${tx.inputs.length}  Out: ${tx.outputs.length}  •  ${tx.sizeBytes}B',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
      trailing: TextButton(
        onPressed: () => _showComingSoonModal(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      dense: true,
      visualDensity: VisualDensity.compact,
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
            Icons.schedule,
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
