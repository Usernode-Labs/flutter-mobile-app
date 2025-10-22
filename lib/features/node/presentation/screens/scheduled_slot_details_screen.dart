import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';

class ScheduledSlotDetailsScreen extends StatelessWidget {
  final RpcEpochWonSlot slot;

  const ScheduledSlotDetailsScreen({
    super.key,
    required this.slot,
  });

  String _formatDateTime(BigInt timestampMs) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestampMs.toInt(),
      isUtc: true,
    ).toLocal();
    final dateFormat = DateFormat('HH:mm:ss.S, dd MMM');
    return dateFormat.format(dateTime);
  }

  bool _isPast(BigInt timestampMs) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestampMs.toInt(),
      isUtc: true,
    );
    return DateTime.now().toUtc().isAfter(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedTime = _formatDateTime(slot.expectedTimeMs);
    final isPast = _isPast(slot.expectedTimeMs);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Scheduled Slot Details',
        showNotifications: false,
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
                        'Scheduled Slot at ${slot.globalSlot}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'on $formattedTime',
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

            // Timeline - VRF discovered and scheduled always completed for won slots
            _ScheduledTimelineItem(
              icon: Icons.check,
              title: 'VRF Slot Discovered',
              subtitle: 'Slot ${slot.globalSlot} won',
              timing: null,
              isCompleted: true,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.check,
              title: 'Block Production Scheduled',
              subtitle: 'on $formattedTime',
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
              subtitle: 'Update and Apply UTXOs',
              timing: '-',
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Block Committed',
              subtitle: 'Commit block time',
              timing: null,
              isCompleted: false,
              isLast: false,
            ),

            _ScheduledTimelineItem(
              icon: Icons.circle_outlined,
              title: 'Block Confirmed',
              subtitle: 'Confirm block as Canonical',
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
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
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
      ),
    );
  }
}
