import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class ProducedBlocksScreen extends ConsumerWidget {
  const ProducedBlocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchainAsync = ref.watch(nodeBlockchainProvider);
    final raw = ref.watch(nodeRawStatusProvider).value;

    final blockchain = blockchainAsync.value;
    return Scaffold(
      appBar: const AppAppBar(title: 'Produced Blocks'),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: () {
          if (blockchain == null) {
            return Center(
              child: Text(
                blockchainAsync.isLoading
                    ? 'Loading produced blocks...'
                    : 'No produced blocks available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: blockchainAsync.isLoading
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.error,
                ),
              ),
            );
          }

          final bestTipSlot = raw?.globalSlot;
          final items = blockchain.items.take(100).toList();

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final block = items[i];
              final isBestTip =
                  bestTipSlot != null && block.globalSlot == bestTipSlot;
              String blockHash;
              try {
                blockHash = block.hash.toString();
              } catch (_) {
                blockHash = 'N/A';
              }
              return _ProducedBlockTile(
                block: block,
                isBestTip: isBestTip,
                hash: blockHash,
              );
            },
          );
        }(),
      ),
    );
  }
}

class _ProducedBlockTile extends StatelessWidget {
  final RpcStatusBlockInfo block;
  final bool isBestTip;
  final String hash;
  const _ProducedBlockTile({
    required this.block,
    required this.isBestTip,
    required this.hash,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Block #${block.height}',
                        style: theme.textTheme.titleMedium),
                    if (isBestTip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('BEST TIP',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text('Epoch ${block.epoch} • Slot ${block.globalSlot}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Hash: ${_shorten(hash)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _shorten(String s, {int head = 6, int tail = 6}) {
    if (s == 'N/A' || s.length <= head + tail + 3) return s;
    return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
  }
}
