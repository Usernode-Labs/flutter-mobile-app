import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

class BlockDetailsScreen extends StatelessWidget {
  final RpcStatusBlockInfo block;

  const BlockDetailsScreen({
    super.key,
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Block Details',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header section with main info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(
                    Icons.check,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Block #${block.height} at Slot ${block.globalSlot}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Epoch ${block.epoch}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Timeline
            _TimelineItem(
              icon: Icons.check,
              title: 'VRF Slot Discovered',
              subtitle: 'Slot ${block.globalSlot} won',
              timing: '5ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Block Production Scheduled',
              subtitle: 'Epoch ${block.epoch}, Slot ${block.globalSlot}',
              timing: null,
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Transaction Batches Included',
              subtitle:
                  'Included ${block.batches.length} batches / ${block.transactions} transactions',
              timing: '<1ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'State Transition.',
              subtitle: 'Protocol and Consensus states updated',
              timing: '<1ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Applied Locally',
              subtitle: '+543 New UTXOs, -210 Spent UTXOs',
              timing: '100ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Block Committed',
              subtitle: 'Block #${block.height}',
              timing: null,
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.shield_outlined,
              title: 'Block Confirmed',
              subtitle:
                  'Hash: ${block.hash.toString().length > 16 ? block.hash.toString().substring(0, 16) : block.hash.toString()}...',
              timing: '250ms',
              isLast: true,
            ),

            const SizedBox(height: 32),

            // Block Information Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Block Information',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Block Hash',
                    value: block.hash.toString().length > 24
                        ? '${block.hash.toString().substring(0, 24)}...'
                        : block.hash.toString(),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Height',
                    value: '${block.height}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Global Slot',
                    value: '${block.globalSlot}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Epoch',
                    value: '${block.epoch}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Producer',
                    value: block.producerPubkey.length > 24
                        ? '${block.producerPubkey.substring(0, 24)}...'
                        : block.producerPubkey,
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Transactions',
                    value: '${block.transactions}',
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Batches',
                    value: '${block.batches.length}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? timing;
  final bool isLast;

  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timing,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: icon == Icons.shield_outlined
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: icon == Icons.shield_outlined
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.surface,
                    size: 14,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
              ],
            ),

            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (timing != null)
                        Text(
                          timing!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
