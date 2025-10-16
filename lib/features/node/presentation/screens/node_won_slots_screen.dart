import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/node/presentation/controllers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:intl/intl.dart';

enum SlotStatus { produced, missed, pending }

class SlotData {
  final RpcEpochWonSlot slot;
  final SlotStatus status;

  const SlotData({required this.slot, required this.status});
}

class TimeBucketStats {
  final DateTime time;
  final int wonSlots;
  final int produced;
  final int missed;
  final int pending;

  const TimeBucketStats({
    required this.time,
    required this.wonSlots,
    required this.produced,
    required this.missed,
    required this.pending,
  });
}

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
      appBar: const AppAppBar(
        title: 'Won Slots',
        showNotifications: false,
      ),
      body: Padding(
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

          Log.d('WON_SLOTS_SCREEN',
              'Epoch: ${rewards.epoch}, Won slots count: ${wonSlots.length}, Produced slots count: ${producedSlots.length}');

          if (wonSlots.isEmpty) {
            return Center(
              child: Text(
                'No won slots data available',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          // Create slot data with status
          final now = DateTime.now().toUtc();
          final slotDataList = wonSlots.map((slot) {
            final isProduced = producedSlots.contains(slot.globalSlot);
            final slotTime = DateTime.fromMillisecondsSinceEpoch(
              slot.expectedTimeMs.toInt(),
              isUtc: true,
            );
            final status = isProduced
                ? SlotStatus.produced
                : (now.isAfter(slotTime)
                    ? SlotStatus.missed
                    : SlotStatus.pending);
            return SlotData(slot: slot, status: status);
          }).toList();

          // Determine epoch duration
          final times = wonSlots.map((s) => DateTime.fromMillisecondsSinceEpoch(
              s.expectedTimeMs.toInt(),
              isUtc: true)).toList();
          times.sort();
          final epochDuration = times.isNotEmpty && times.length > 1
              ? times.last.difference(times.first)
              : Duration.zero;

          // Use hourly grouping if epoch < 3 days, otherwise daily
          final useHourly = epochDuration.inDays < 3;

          // Group by time bucket
          final buckets = _groupByTimeBucket(slotDataList, useHourly);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Epoch ${rewards.epoch}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  useHourly ? 'Grouped by hour' : 'Grouped by day',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Summary card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        context,
                        'Won',
                        wonSlots.length.toString(),
                        colorScheme.secondary,
                      ),
                      _buildSummaryItem(
                        context,
                        'Produced',
                        producedSlots.length.toString(),
                        colorScheme.tertiary,
                      ),
                      _buildSummaryItem(
                        context,
                        'Missed',
                        slotDataList
                            .where((s) => s.status == SlotStatus.missed)
                            .length
                            .toString(),
                        colorScheme.error,
                      ),
                      _buildSummaryItem(
                        context,
                        'Pending',
                        slotDataList
                            .where((s) => s.status == SlotStatus.pending)
                            .length
                            .toString(),
                        colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Time buckets
                ...buckets.map((bucket) => _buildTimeBucket(
                      context,
                      theme,
                      colorScheme,
                      bucket,
                      useHourly,
                    )),
              ],
            ),
          );
        }(),
      ),
    );
  }

  List<TimeBucketStats> _groupByTimeBucket(
      List<SlotData> slots, bool useHourly) {
    final Map<String, List<SlotData>> grouped = {};

    for (final slotData in slots) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        slotData.slot.expectedTimeMs.toInt(),
        isUtc: true,
      );

      final String key;
      if (useHourly) {
        // Group by hour
        key =
            '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}-${time.hour.toString().padLeft(2, '0')}';
      } else {
        // Group by day
        key =
            '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(slotData);
    }

    // Convert to stats
    final stats = grouped.entries.map((entry) {
      final slots = entry.value;
      final firstSlot = slots.first;
      final time = DateTime.fromMillisecondsSinceEpoch(
        firstSlot.slot.expectedTimeMs.toInt(),
        isUtc: true,
      );

      return TimeBucketStats(
        time: useHourly
            ? DateTime(time.year, time.month, time.day, time.hour)
            : DateTime(time.year, time.month, time.day),
        wonSlots: slots.length,
        produced: slots.where((s) => s.status == SlotStatus.produced).length,
        missed: slots.where((s) => s.status == SlotStatus.missed).length,
        pending: slots.where((s) => s.status == SlotStatus.pending).length,
      );
    }).toList();

    // Sort by time (oldest first)
    stats.sort((a, b) => a.time.compareTo(b.time));

    return stats;
  }

  Widget _buildSummaryItem(
      BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
        ),
      ],
    );
  }

  Widget _buildTimeBucket(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    TimeBucketStats bucket,
    bool useHourly,
  ) {
    final now = DateTime.now();
    final isToday = bucket.time.year == now.year &&
        bucket.time.month == now.month &&
        bucket.time.day == now.day;

    final String timeLabel;
    if (useHourly) {
      if (isToday) {
        timeLabel =
            'Today ${bucket.time.hour.toString().padLeft(2, '0')}:00';
      } else {
        timeLabel = DateFormat('MMM d, HH:00').format(bucket.time.toLocal());
      }
    } else {
      if (isToday) {
        timeLabel = 'Today';
      } else {
        timeLabel = DateFormat('MMM d, yyyy').format(bucket.time.toLocal());
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time header
          Row(
            children: [
              Icon(
                useHourly ? Icons.access_time : Icons.calendar_today,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                timeLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip(
                context,
                'Won',
                bucket.wonSlots,
                colorScheme.secondaryContainer,
                colorScheme.onSecondaryContainer,
              ),
              _buildStatChip(
                context,
                'Produced',
                bucket.produced,
                colorScheme.tertiaryContainer,
                colorScheme.onTertiaryContainer,
              ),
              _buildStatChip(
                context,
                'Missed',
                bucket.missed,
                colorScheme.errorContainer,
                colorScheme.onErrorContainer,
              ),
              _buildStatChip(
                context,
                'Pending',
                bucket.pending,
                colorScheme.primaryContainer,
                colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, int count,
      Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
