import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/slot_heatmap.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';

class NodeWonSlotsScreen extends ConsumerWidget {
  const NodeWonSlotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rewardsAsync = ref.watch(nodeEpochRewardsProvider);
    final blockchainAsync = ref.watch(nodeBlockchainProvider);

    final rewards = rewardsAsync.value;
    final blockchain = blockchainAsync.value;

    return Scaffold(
      appBar: const AppAppBar(title: 'Won Slots'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: () {
            if (rewards == null || blockchain == null) {
              return Center(
                child: Text(
                  (rewardsAsync.isLoading || blockchainAsync.isLoading)
                      ? 'Loading epoch data...'
                      : 'Epoch data unavailable',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: (rewardsAsync.isLoading || blockchainAsync.isLoading)
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.error,
                  ),
                ),
              );
            }

            final producedSlots = blockchain.items
                .where((b) => b.epoch == rewards.epoch)
                .map((b) => b.globalSlot)
                .toSet();
            final wonSlots = rewards.wonSlots ?? [];

            final data = wonSlots.map((slot) {
              final isProduced = producedSlots.contains(slot.globalSlot);
              final now = DateTime.now().toUtc();
              final slotTime = DateTime.fromMillisecondsSinceEpoch(
                slot.expectedTimeMs.toInt(),
                isUtc: true,
              );
              final status = isProduced
                  ? SlotHeatmapStatus.produced
                  : (now.isAfter(slotTime)
                      ? SlotHeatmapStatus.missed
                      : SlotHeatmapStatus.pending);
              return SlotHeatmapData(slot: slot, status: status);
            }).toList();

            if (data.isEmpty) {
              return Center(
                child: Text(
                  'No won slots data available',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Epoch ${rewards.epoch}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SlotHeatmap(
                    slots: data,
                    cellSize: 12,
                    cellSpacing: 6,
                  ),
                ],
              ),
            );
          }(),
        ),
      ),
    );
  }
}

