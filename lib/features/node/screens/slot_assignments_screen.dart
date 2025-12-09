import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/features/node/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';

class SlotAssignmentsScreen extends StatefulWidget {
  const SlotAssignmentsScreen({super.key, this.args});
  final Map<String, dynamic>? args;

  @override
  State<SlotAssignmentsScreen> createState() => _SlotAssignmentsScreenState();
}

enum _Filter { all, produced, missed, upcoming }

class _AssignmentItem {
  final int slot;
  final RpcSlotResult result;
  final int? slotTimeMs;
  final Map<String, dynamic>? producedMeta;
  const _AssignmentItem({
    required this.slot,
    required this.result,
    this.slotTimeMs,
    this.producedMeta,
  });
}

class _SlotAssignmentsScreenState extends State<SlotAssignmentsScreen> {
  final Set<_Filter> _selected = {_Filter.all};
  late final List<_AssignmentItem> _items =
      _buildItemsFromArgs(widget.args) ?? const <_AssignmentItem>[];

  @override
  void initState() {
    super.initState();
    // Initialize selected filters from args if provided
    final filters = (widget.args?['filters'] as List?)?.cast<String>();
    if (filters != null && filters.isNotEmpty) {
      final Set<_Filter> initial = {};
      if (filters.contains('all')) {
        initial.add(_Filter.all);
      } else {
        if (filters.contains('produced')) initial.add(_Filter.produced);
        if (filters.contains('missed')) initial.add(_Filter.missed);
        if (filters.contains('upcoming')) initial.add(_Filter.upcoming);
        if (initial.isEmpty) initial.add(_Filter.all);
      }
      _selected
        ..clear()
        ..addAll(initial);
    }
  }

  List<_AssignmentItem>? _buildItemsFromArgs(Map<String, dynamic>? args) {
    if (args == null) return null;
    try {
      final epoch = args['epoch'] as int?;
      final slotsInEpoch = args['slotsInEpoch'] as int?;
      final results = (args['results'] as List?)?.cast<int>();
      final timesDynamic = (args['slotTimesMs'] as List?);
      final List<int?> slotTimesMs = timesDynamic == null
          ? const []
          : timesDynamic.map((e) {
              if (e == null) return null;
              if (e is int) return e;
              if (e is String) return int.tryParse(e);
              return null;
            }).toList();
      final producedMetaDynamic = (args['producedMeta'] as List?);
      final List<Map<String, dynamic>?> producedMeta = producedMetaDynamic ==
              null
          ? const []
          : producedMetaDynamic
              .map((e) => e == null ? null : (e as Map).cast<String, dynamic>())
              .toList();
      if (epoch == null || slotsInEpoch == null || results == null) return null;
      return List<_AssignmentItem>.generate(slotsInEpoch, (i) {
        var r;
        if (i < results.length) {
          r = RpcSlotResult.values[results[i]];
        } else {
          r = RpcSlotResult.notCalculated;
        }
        return _AssignmentItem(
          slot: i,
          result: r,
          slotTimeMs: i < slotTimesMs.length ? slotTimesMs[i] : null,
          producedMeta: i < producedMeta.length ? producedMeta[i] : null,
        );
      }).reversed.toList();
    } catch (_) {
      return null;
    }
  }

  bool _matchesFilters(_AssignmentItem item) {
    // When no filters are selected, show everything.
    if (_selected.isEmpty) {
      return true;
    }

    final wantsWonSlots = _selected.contains(_Filter.all) &&
        (item.result == RpcSlotResult.produced ||
            item.result == RpcSlotResult.orphaned ||
            item.result == RpcSlotResult.missed ||
            item.result == RpcSlotResult.scheduled);
    final wantsProduced = _selected.contains(_Filter.produced) &&
        (item.result == RpcSlotResult.produced ||
            item.result == RpcSlotResult.orphaned);
    final wantsMissed = _selected.contains(_Filter.missed) &&
        item.result == RpcSlotResult.missed;
    final wantsUpcoming = _selected.contains(_Filter.upcoming) &&
        item.result == RpcSlotResult.scheduled;
    return wantsWonSlots || wantsProduced || wantsMissed || wantsUpcoming;
  }

  void _toggleFilter(_Filter filter) {
    setState(() {
      // Single-select behavior:
      // - Tapping an already-selected filter clears all (shows everything).
      // - Tapping a different filter selects only that one.
      if (_selected.contains(filter)) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..add(filter);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    final filtered = _items.where(_matchesFilters).toList(growable: false);
    final args = widget.args ?? const <String, dynamic>{};
    final epoch = (args['epoch'] as int?) ?? 0;
    final slotsInEpoch = (args['slotsInEpoch'] as int?) ?? 0;
    // Progress now driven by live node status; results not needed here

    // Precompute counts for each filter for display in chips.
    final producedCount = _items
        .where((i) =>
            i.result == RpcSlotResult.produced ||
            i.result == RpcSlotResult.orphaned)
        .length;
    final missedCount =
        _items.where((i) => i.result == RpcSlotResult.missed).length;
    final upcomingCount =
        _items.where((i) => i.result == RpcSlotResult.scheduled).length;
    final wonSlotsCount = producedCount + missedCount + upcomingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot Assignments'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header KPI card
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceBright,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Epoch $epoch',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Consumer(builder: (context, ref, _) {
                          final summary =
                              ref.watch(producedBlocksSummaryProvider);
                          final data = summary.asData?.value;
                          final total = data?.slotsInEpoch ?? slotsInEpoch;
                          final currentEpoch = data?.currentEpoch;
                          final isCurrentEpoch =
                              currentEpoch != null && currentEpoch == epoch;
                          final isFutureEpoch =
                              currentEpoch != null && epoch > currentEpoch;

                          int curr;
                          if (data == null || total <= 0) {
                            curr = 0;
                          } else if (isCurrentEpoch) {
                            curr = data.currentEpochSlot;
                          } else if (isFutureEpoch) {
                            curr = 0;
                          } else {
                            // Past epoch: fully completed
                            curr = total;
                          }

                          return Text(
                            'Slot Progress: $curr / $total',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: secondary),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer(builder: (context, ref, _) {
                      final summary = ref.watch(producedBlocksSummaryProvider);
                      final data = summary.asData?.value;
                      final total = data?.slotsInEpoch ?? slotsInEpoch;
                      final currentEpoch = data?.currentEpoch;
                      final isCurrentEpoch =
                          currentEpoch != null && currentEpoch == epoch;
                      final isFutureEpoch =
                          currentEpoch != null && epoch > currentEpoch;

                      int curr;
                      if (data == null || total <= 0) {
                        curr = 0;
                      } else if (isCurrentEpoch) {
                        curr = data.currentEpochSlot;
                      } else if (isFutureEpoch) {
                        curr = 0;
                      } else {
                        // Past epoch: fully completed
                        curr = total;
                      }

                      final p = total > 0 ? (curr / total) : 0.0;
                      return _ProgressBar(progress: p);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Filters row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Won Slots',
                      count: wonSlotsCount,
                      selected: _selected.contains(_Filter.all),
                      onTap: () => _toggleFilter(_Filter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Produced',
                      count: producedCount,
                      selected: _selected.contains(_Filter.produced),
                      onTap: () => _toggleFilter(_Filter.produced),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Missed',
                      count: missedCount,
                      selected: _selected.contains(_Filter.missed),
                      onTap: () => _toggleFilter(_Filter.missed),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Upcoming',
                      count: upcomingCount,
                      selected: _selected.contains(_Filter.upcoming),
                      onTap: () => _toggleFilter(_Filter.upcoming),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // List title
              Text(
                'Assignments',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Filtered list of slots (demo data)
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isScheduled = item.result == RpcSlotResult.scheduled;
                    final isProduced = item.result == RpcSlotResult.produced;
                    final isMissed = item.result == RpcSlotResult.missed;
                    final isOrphaned = item.result == RpcSlotResult.orphaned;
                    String subtitleText = '';
                    if (item.slotTimeMs != null &&
                        (isScheduled || isProduced || isMissed || isOrphaned)) {
                      final dt =
                          DateTime.fromMillisecondsSinceEpoch(item.slotTimeMs!);
                      final hh = dt.hour.toString().padLeft(2, '0');
                      final mm = dt.minute.toString().padLeft(2, '0');
                      if (isScheduled) {
                        subtitleText = 'Scheduled for $hh:$mm';
                      } else if (isProduced) {
                        subtitleText = 'Produced at $hh:$mm';
                      } else if (isMissed) {
                        subtitleText = 'Missed at $hh:$mm';
                      } else if (isOrphaned) {
                        subtitleText = 'Orphaned at $hh:$mm';
                      }
                    }
                    final VoidCallback? onTap = (isProduced || isOrphaned)
                        ? () {
                            context.push(
                              AppRoutes.producedBlockDetails,
                              extra: {
                                'epoch': epoch,
                                'slot': item.slot,
                                'metadata': item.producedMeta,
                              },
                            );
                          }
                        : null;
                    return _SlotRow(
                      icon: Icons.layers,
                      title: 'Slot ${item.slot}',
                      subtitle: subtitleText,
                      result: item.result,
                      onTap: onTap,
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: filtered.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Match ProducedBlocksScreen epoch panel colors:
    // - Light: grey track + black active
    // - Dark: surfaceVariant track + primary active
    final trackColor =
        isDark ? colorScheme.surfaceVariant : Colors.grey.shade300;
    final activeColor = isDark ? colorScheme.primary : Colors.black87;

    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      height: 12,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          FractionallySizedBox(
            widthFactor: p,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 4,
              height: 8,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.result,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final RpcSlotResult result;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Center(child: Icon(icon, color: theme.colorScheme.onSurface)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$subtitle',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: secondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              result == RpcSlotResult.produced
                  ? 'Produced'
                  : result == RpcSlotResult.orphaned
                      ? 'Orphaned'
                      : result == RpcSlotResult.missed
                          ? 'Missed'
                          : result == RpcSlotResult.scheduled
                              ? 'Upcoming'
                              : result == RpcSlotResult.notCalculated
                                  ? 'Not Calculated'
                                  : result == RpcSlotResult.notWon
                                      ? 'Not Won'
                                      : 'Unknown',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: result == RpcSlotResult.orphaned
                    ? Colors.orange
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            if (result == RpcSlotResult.produced ||
                result == RpcSlotResult.orphaned)
              const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? Colors.black87 : Colors.transparent;
    final fg = selected ? Colors.white : theme.colorScheme.onSurface;
    final border = selected ? Colors.black87 : theme.colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
