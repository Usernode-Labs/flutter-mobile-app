import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/produced_block_card.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_raw_status_provider.dart';

class ProducedBlocksScreen extends ConsumerStatefulWidget {
  const ProducedBlocksScreen({super.key});

  @override
  ConsumerState<ProducedBlocksScreen> createState() =>
      _ProducedBlocksScreenState();
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
              return ProducedBlockCard(
                block: block,
                isBestTip: isBestTip,
                customHash: blockHash,
                rewardPerBlock: rewardPerBlock,
                variant: BlockCardVariant.standard,
              );
            },
          );
        }(),
      ),
    );
  }
}
