import 'package:flutter/material.dart';

class ScheduledSlotDetailsScreen extends StatelessWidget {
  final int slotNumber;

  const ScheduledSlotDetailsScreen({
    super.key,
    required this.slotNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Scheduled at slot $slotNumber'),
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
                    Icons.schedule,
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
                        'Scheduled Slot at $slotNumber',
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

            // Timeline - first two completed, rest pending
            _ScheduledTimelineItem(
              icon: Icons.check,
              title: 'VRF Slot Discovered',
              subtitle: '0.0012/0.0013',
              timing: '5ms',
              isCompleted: true,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.check,
              title: 'Block Production Scheduled',
              subtitle: 'on 17:45:04.1, 08 Sep',
              timing: null,
              isCompleted: true,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Transaction Batches Included',
              subtitle: 'Included - (Max) / - available',
              timing: '-',
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'State Transition.',
              subtitle: 'Protocol and Consensus states updated',
              timing: '-',
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Applied Locally',
              subtitle: '+543 New UTXOs, -210 Spent UTXOs',
              timing: '-',
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Block Committed',
              subtitle: 'on 17:45:04.1, 08 Sep',
              timing: null,
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Block Confirmed',
              subtitle: 'as Canonical (3 Confirmations)',
              timing: '-',
              isCompleted: false,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledTimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? timing;
  final bool isCompleted;
  final bool isLast;

  const _ScheduledTimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.timing,
    required this.isCompleted,
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
                  color: isCompleted
                      ? theme.colorScheme.onSurface
                      : Colors.transparent,
                  border: isCompleted
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outline,
                          width: 2,
                        ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: isCompleted
                      ? theme.colorScheme.surface
                      : theme.colorScheme.outline,
                  size: 14,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 60,
                  color: theme.colorScheme.outline.withOpacity(0.3),
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
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
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
