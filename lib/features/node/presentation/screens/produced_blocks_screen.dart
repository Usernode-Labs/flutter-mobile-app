import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class ProducedBlocksScreen extends ConsumerStatefulWidget {
  const ProducedBlocksScreen({super.key});

  @override
  ConsumerState<ProducedBlocksScreen> createState() => _ProducedBlocksScreenState();
}

class _ProducedBlocksScreenState extends ConsumerState<ProducedBlocksScreen> {
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
      await Future.wait([
        ref.read(nodeBlockchainProvider.notifier).refresh(),
        ref.read(nodeRawStatusProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final blockchainAsync = ref.watch(nodeBlockchainProvider);
    final raw = ref.watch(nodeRawStatusProvider).value;
    final rewardsAsync = ref.watch(nodeEpochRewardsProvider);

    final blockchain = blockchainAsync.value;
    final rewards = rewardsAsync.value;
    final rewardPerBlock = rewards?.rewardPerBlock ?? BigInt.zero;

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Produced Blocks',
        showNotifications: false,
      ),
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
                rewardPerBlock: rewardPerBlock,
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
  final BigInt rewardPerBlock;
  const _ProducedBlockTile({
    required this.block,
    required this.isBestTip,
    required this.hash,
    required this.rewardPerBlock,
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
          Icon(Icons.auto_awesome_motion, color: colorScheme.primary, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Block #${block.height}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        )),
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
                                fontWeight: FontWeight.bold,
                                fontSize: 9)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text('Epoch ${block.epoch} • Slot ${block.globalSlot}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    )),
                const SizedBox(height: 2),
                Text(_formatTimestamp(block.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    )),
                const SizedBox(height: 2),
                Text('Hash: ${_shorten(hash)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                    )),
              ],
            ),
          ),

          // TKN amount
          Text(
            '+${_formatTokenAmount(rewardPerBlock)} TKN',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _shorten(String s, {int head = 6, int tail = 6}) {
    if (s == 'N/A' || s.length <= head + tail + 3) return s;
    return '${s.substring(0, head)}...${s.substring(s.length - tail)}';
  }

  String _formatTokenAmount(BigInt amount) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(amount.toInt());
  }

  String _formatTimestamp(BigInt timestampMs) {
    try {
      final millis = timestampMs.toInt();
      final blockTime = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
      final now = DateTime.now();
      final diff = now.difference(blockTime);

      // Calculate relative time
      String relativeTime;
      if (diff.inMinutes < 1) {
        relativeTime = 'just now';
      } else if (diff.inMinutes < 60) {
        relativeTime = '${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'} ago';
      } else if (diff.inHours < 24) {
        relativeTime = '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      } else if (diff.inDays < 7) {
        relativeTime = '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      } else {
        relativeTime = '${(diff.inDays / 7).floor()} week${(diff.inDays / 7).floor() == 1 ? '' : 's'} ago';
      }

      // Format absolute time
      final hour = blockTime.hour.toString().padLeft(2, '0');
      final minute = blockTime.minute.toString().padLeft(2, '0');
      final second = blockTime.second.toString().padLeft(2, '0');
      final absoluteTime = '$hour:$minute:$second';

      return '$relativeTime • $absoluteTime';
    } catch (e) {
      return 'Invalid time';
    }
  }
}
