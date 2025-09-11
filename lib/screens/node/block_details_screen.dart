import 'package:flutter/material.dart';

class BlockDetailsScreen extends StatelessWidget {
  final int blockNumber;

  const BlockDetailsScreen({
    super.key,
    required this.blockNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Produced block at $blockNumber'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: false,
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
                        'Produced at Slot $blockNumber',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'on 17:45:04.1, 08 Sep',
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
              subtitle: '0.0012/0.0013',
              timing: '5ms',
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Block Production Scheduled',
              subtitle: 'on 17:45:04.1, 08 Sep',
              timing: null,
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.check,
              title: 'Transaction Batches Included',
              subtitle: 'Included 10 (Max) / 10 available',
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
              subtitle: 'on 17:45:04.1, 08 Sep',
              timing: null,
              isLast: false,
            ),

            _TimelineItem(
              icon: Icons.shield_outlined,
              title: 'Block Confirmed',
              subtitle: 'as Canonical (3 Confirmations)',
              timing: '250ms',
              isLast: true,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  fontWeight: FontWeight.w800,
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
    );
  }
}
