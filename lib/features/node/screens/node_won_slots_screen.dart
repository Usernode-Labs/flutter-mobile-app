import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_rewards.dart';
import 'package:intl/intl.dart';

final _log = LoggingService.instance.withTag('usernode/NodeWonSlotsScreen');

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

class NodeWonSlotsScreen extends ConsumerStatefulWidget {
  const NodeWonSlotsScreen({super.key});

  @override
  ConsumerState<NodeWonSlotsScreen> createState() => _NodeWonSlotsScreenState();
}

class _NodeWonSlotsScreenState extends ConsumerState<NodeWonSlotsScreen> {
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
        ref.read(epochRewardsProvider.notifier).refresh(),
        ref.read(nodeBlockchainProvider.notifier).refresh(),
      ]);
    } finally {
      if (mounted) {
        _refreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final rewardsAsync = ref.watch(epochRewardsProvider);
    final blockchainAsync = ref.watch(nodeBlockchainProvider);

    final rewards = rewardsAsync.value;
    final blockchain = blockchainAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.wonSlotsTitle),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: () {
          if (rewards == null || blockchain == null) {
            return Center(
              child: Text(
                (rewardsAsync.isLoading || blockchainAsync.isLoading)
                    ? l10n.wonSlotsLoadingEpoch
                    : l10n.wonSlotsEpochUnavailable,
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
          final wonSlots = rewards.wonSlots;

          _log.trace(
              'Epoch: ${rewards.epoch}, Won slots count: ${wonSlots.length}, Produced slots count: ${producedSlots.length}');

          if (wonSlots.isEmpty) {
            return Center(
              child: Text(
                l10n.wonSlotsNoData,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          // Create slot data with status
          final now = DateTime.now();
          final slotDataList = wonSlots.map((slot) {
            final isProduced = producedSlots.contains(slot.globalSlot);
            final slotTime = DateTime.fromMillisecondsSinceEpoch(
              slot.expectedTimeMs.toInt(),
              isUtc: true,
            ).toLocal();
            final status = isProduced
                ? SlotStatus.produced
                : (now.isAfter(slotTime)
                    ? SlotStatus.missed
                    : SlotStatus.pending);
            return SlotData(slot: slot, status: status);
          }).toList();

          // Determine epoch duration
          final times = wonSlots
              .map((s) => DateTime.fromMillisecondsSinceEpoch(
                      s.expectedTimeMs.toInt(),
                      isUtc: true)
                  .toLocal())
              .toList();
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
                SizedBox(height: spacing.space4),
                Text(
                  useHourly
                      ? l10n.wonSlotsGroupedByHour
                      : l10n.wonSlotsGroupedByDay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: spacing.space16),

                // Summary card
                AppCard.compact(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: radii.borderRadiusSmall,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                        context,
                        l10n.wonSlotsWon,
                        wonSlots.length.toString(),
                        colorScheme.secondary,
                      ),
                      _buildSummaryItem(
                        context,
                        l10n.wonSlotsProduced,
                        producedSlots.length.toString(),
                        colorScheme.tertiary,
                      ),
                      _buildSummaryItem(
                        context,
                        l10n.wonSlotsMissed,
                        slotDataList
                            .where((s) => s.status == SlotStatus.missed)
                            .length
                            .toString(),
                        colorScheme.error,
                      ),
                      _buildSummaryItem(
                        context,
                        l10n.wonSlotsPending,
                        slotDataList
                            .where((s) => s.status == SlotStatus.pending)
                            .length
                            .toString(),
                        colorScheme.primary,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: spacing.space16),

                // Time buckets
                ...buckets.map((bucket) => _buildTimeBucket(
                      context,
                      theme,
                      colorScheme,
                      bucket,
                      useHourly,
                      l10n,
                    )),
                SizedBox(height: spacing.space32),
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
      ).toLocal();

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
      ).toLocal();

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
    final spacing = Theme.of(context).extension<AppSpacing>()!;
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
        SizedBox(height: spacing.space4),
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
    AppLocalizations l10n,
  ) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final now = DateTime.now();
    final isToday = bucket.time.year == now.year &&
        bucket.time.month == now.month &&
        bucket.time.day == now.day;

    final String timeLabel;
    if (useHourly) {
      if (isToday) {
        timeLabel =
            '${l10n.wonSlotsToday} ${bucket.time.hour.toString().padLeft(2, '0')}:00';
      } else {
        timeLabel = DateFormat('MMM d, HH:00').format(bucket.time);
      }
    } else {
      if (isToday) {
        timeLabel = l10n.wonSlotsToday;
      } else {
        timeLabel = DateFormat('MMM d, yyyy').format(bucket.time);
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space8),
      child: AppCard.compact(
        color: colorScheme.surfaceContainer,
        borderRadius: radii.borderRadiusSmall,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time header
            Row(
              children: [
                Icon(
                  useHourly
                      ? Symbols.access_time_sharp
                      : Symbols.calendar_today_sharp,
                  size: sizing.iconXSmall,
                  color: colorScheme.primary,
                ),
                SizedBox(width: spacing.space8),
                Text(
                  timeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.space8),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  context,
                  l10n.wonSlotsWon,
                  bucket.wonSlots,
                  colorScheme.secondaryContainer,
                  colorScheme.onSecondaryContainer,
                ),
                _buildStatChip(
                  context,
                  l10n.wonSlotsProduced,
                  bucket.produced,
                  colorScheme.tertiaryContainer,
                  colorScheme.onTertiaryContainer,
                ),
                _buildStatChip(
                  context,
                  l10n.wonSlotsMissed,
                  bucket.missed,
                  colorScheme.errorContainer,
                  colorScheme.onErrorContainer,
                ),
                _buildStatChip(
                  context,
                  l10n.wonSlotsPending,
                  bucket.pending,
                  colorScheme.primaryContainer,
                  colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, int count,
      Color bgColor, Color textColor) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: spacing.space8, vertical: spacing.space8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: radii.borderRadiusSmall,
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
          SizedBox(height: spacing.space4),
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
