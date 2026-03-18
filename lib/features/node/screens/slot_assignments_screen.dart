import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/utils/time_format.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/epoch_slots.dart';

class SlotAssignmentsScreen extends ConsumerStatefulWidget {
  const SlotAssignmentsScreen({super.key, this.args});
  final Map<String, dynamic>? args;

  @override
  ConsumerState<SlotAssignmentsScreen> createState() =>
      _SlotAssignmentsScreenState();
}

enum _Filter { wonSlots, produced, missed, upcoming }

/// Chip order — used for both building chips and resolving tap indices.
const _chipOrder = [
  _Filter.wonSlots,
  _Filter.produced,
  _Filter.missed,
  _Filter.upcoming
];

class _ParsedItem {
  final int slot;
  final RpcSlotResult result;
  final int? slotTimeMs;
  final Map<String, dynamic>? producedMeta;
  const _ParsedItem({
    required this.slot,
    required this.result,
    this.slotTimeMs,
    this.producedMeta,
  });
}

class _SlotAssignmentsScreenState extends ConsumerState<SlotAssignmentsScreen> {
  _Filter _selected = _Filter.wonSlots;
  bool _isInitialFilter = true;
  Timer? _autoRefreshTimer;
  bool _refreshing = false;
  late final List<_ParsedItem> _fallbackItems =
      _buildItemsFromArgs(widget.args) ?? const <_ParsedItem>[];

  @override
  void initState() {
    super.initState();
    final filters = (widget.args?['filters'] as List?)?.cast<String>();
    if (filters != null && filters.isNotEmpty) {
      if (filters.contains('all')) {
        _selected = _Filter.wonSlots;
      } else if (filters.contains('produced')) {
        _selected = _Filter.produced;
      } else if (filters.contains('missed')) {
        _selected = _Filter.missed;
      } else if (filters.contains('upcoming')) {
        _selected = _Filter.upcoming;
      } else {
        _selected = _Filter.wonSlots;
      }
    } else {
      _selected = _Filter.wonSlots;
    }

    _startAutoRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSummary();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _refreshing) return;
      _refreshSummary();
    });
  }

  Future<void> _refreshSummary() async {
    if (_refreshing) return;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _refreshing = true;
    try {
      final _ = await ref.refresh(producedBlocksSummaryProvider.future);
    } catch (e, st) {
      debugPrint('SlotAssignmentsScreen: refresh failed: $e\n$st');
    } finally {
      _refreshing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Args parsing (reused from old screen)
  // ---------------------------------------------------------------------------

  List<_ParsedItem>? _buildItemsFromArgs(Map<String, dynamic>? args) {
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
      return List<_ParsedItem>.generate(slotsInEpoch, (i) {
        RpcSlotResult r;
        if (i < results.length) {
          r = RpcSlotResult.values[results[i]];
        } else {
          r = RpcSlotResult.notCalculated;
        }
        return _ParsedItem(
          slot: i,
          result: r,
          slotTimeMs: i < slotTimesMs.length ? slotTimesMs[i] : null,
          producedMeta: i < producedMeta.length ? producedMeta[i] : null,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('SlotAssignmentsScreen: failed to parse args: $e\n$st');
      return null;
    }
  }

  List<_ParsedItem>? _buildItemsFromLiveSummary(
    ProducedBlocksSummary? summary,
    int epoch,
    int fallbackSlotsInEpoch,
  ) {
    if (summary == null || epoch < 0 || epoch >= summary.epochScores.length) {
      return null;
    }

    final slotData = summary.epochScores[epoch].epochData.slotData;
    if (slotData == null) return null;

    final slotsInEpoch =
        summary.slotsInEpoch > 0 ? summary.slotsInEpoch : fallbackSlotsInEpoch;
    if (slotsInEpoch <= 0) return null;

    return List<_ParsedItem>.generate(slotsInEpoch, (i) {
      final slot = i < slotData.length ? slotData[i] : null;
      final metadata = slot?.producedBlockMetadata;
      return _ParsedItem(
        slot: i,
        result: slot?.result ?? RpcSlotResult.notCalculated,
        slotTimeMs: slot?.slotTimeMs?.toInt(),
        producedMeta: metadata == null
            ? null
            : <String, dynamic>{
                'blockHash': metadata.blockHash.toString(),
                'canonical': metadata.canonical,
                'timestampMs': metadata.timestampMs.toString(),
                'tokensWon': metadata.tokensWon.toString(),
              },
      );
    });
  }

  static RpcSlotResult _effectiveResult(
    _ParsedItem item,
    int nowMs,
    int slotDurationMs,
  ) {
    if (item.result == RpcSlotResult.scheduled &&
        item.slotTimeMs != null &&
        slotDurationMs > 0 &&
        nowMs >= item.slotTimeMs! + slotDurationMs) {
      return RpcSlotResult.missed;
    }
    return item.result;
  }

  // ---------------------------------------------------------------------------
  // Data mapping helpers
  // ---------------------------------------------------------------------------

  static SlotStatus _mapStatus(RpcSlotResult r) => switch (r) {
        RpcSlotResult.produced => SlotStatus.produced,
        RpcSlotResult.orphaned => SlotStatus.orphaned,
        RpcSlotResult.missed => SlotStatus.missed,
        RpcSlotResult.scheduled => SlotStatus.upcoming,
        RpcSlotResult.notCalculated => SlotStatus.notCalculated,
        RpcSlotResult.notWon => SlotStatus.notWon,
      };

  static String? _formatTimeLabel(RpcSlotResult result, int? slotTimeMs) {
    if (slotTimeMs == null) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(slotTimeMs);
    final timeStr = formatHHMMSS(dt);
    return switch (result) {
      RpcSlotResult.scheduled => 'Scheduled for $timeStr',
      RpcSlotResult.produced => 'Produced at $timeStr',
      RpcSlotResult.missed => 'Missed at $timeStr',
      RpcSlotResult.orphaned => 'Orphaned at $timeStr',
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Filter logic
  // ---------------------------------------------------------------------------

  bool _matchesFilter(_ParsedItem item, int nowMs, int slotDurationMs) {
    final result = _effectiveResult(item, nowMs, slotDurationMs);
    return switch (_selected) {
      _Filter.wonSlots => result == RpcSlotResult.produced ||
          result == RpcSlotResult.orphaned ||
          result == RpcSlotResult.missed ||
          result == RpcSlotResult.scheduled,
      _Filter.produced =>
        result == RpcSlotResult.produced || result == RpcSlotResult.orphaned,
      _Filter.missed => result == RpcSlotResult.missed,
      _Filter.upcoming => result == RpcSlotResult.scheduled,
    };
  }

  void _onFilterTap(int index) {
    final tapped = _chipOrder[index];
    _isInitialFilter = false;
    setState(() {
      _selected = _selected == tapped ? _Filter.wonSlots : tapped;
    });
  }

  // ---------------------------------------------------------------------------
  // Slot progress from live provider
  // ---------------------------------------------------------------------------

  (int current, int total, double fraction) _slotProgress(
    ProducedBlocksSummary? data,
    int epoch,
    int fallbackSlotsInEpoch,
  ) {
    final total = data?.slotsInEpoch ?? fallbackSlotsInEpoch;
    if (data == null || total <= 0) return (0, total, 0.0);

    final currentEpoch = data.currentEpoch;
    int curr;
    if (currentEpoch == epoch) {
      curr = data.currentEpochSlot;
    } else if (epoch > currentEpoch) {
      curr = 0;
    } else {
      curr = total; // past epoch
    }
    return (curr, total, curr / total);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final args = widget.args ?? const <String, dynamic>{};
    final epoch = (args['epoch'] as int?) ?? 0;
    final slotsInEpoch = (args['slotsInEpoch'] as int?) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final slotDurationMs =
        ref.watch(nodeStatusProvider).valueOrNull?.slotDurationMs ?? 0;

    // Live slot progress
    final summary = ref.watch(producedBlocksSummaryProvider);
    final data = summary.valueOrNull;
    final (curr, total, progress) = _slotProgress(data, epoch, slotsInEpoch);
    final items =
        _buildItemsFromLiveSummary(data, epoch, slotsInEpoch) ?? _fallbackItems;

    // Filter counts
    final producedCount = items.where((i) {
      final result = _effectiveResult(i, nowMs, slotDurationMs);
      return result == RpcSlotResult.produced ||
          result == RpcSlotResult.orphaned;
    }).length;
    final missedCount = items
        .where((i) =>
            _effectiveResult(i, nowMs, slotDurationMs) == RpcSlotResult.missed)
        .length;
    final upcomingCount = items
        .where((i) =>
            _effectiveResult(i, nowMs, slotDurationMs) ==
            RpcSlotResult.scheduled)
        .length;
    final wonSlotsCount = producedCount + missedCount + upcomingCount;

    // Build filtered + sorted item list
    final List<_ParsedItem> filtered;
    if (_selected == _Filter.upcoming) {
      filtered = items
          .where((item) => _matchesFilter(item, nowMs, slotDurationMs))
          .toList(growable: false);
    } else {
      filtered = items.reversed
          .where((item) => _matchesFilter(item, nowMs, slotDurationMs))
          .toList(growable: false);
    }

    final dsItems = filtered.map((item) {
      final result = _effectiveResult(item, nowMs, slotDurationMs);
      final isTappable =
          result == RpcSlotResult.produced || result == RpcSlotResult.orphaned;
      return SlotAssignmentItemData(
        slot: item.slot,
        status: _mapStatus(result),
        timeLabel: _formatTimeLabel(result, item.slotTimeMs),
        isTappable: isTappable,
      );
    }).toList(growable: false);

    final highlightIndex = _isInitialFilter &&
            filtered.isNotEmpty &&
            (_selected == _Filter.produced ||
                _selected == _Filter.missed ||
                _selected == _Filter.upcoming)
        ? 0
        : null;

    return SlotAssignmentsPage(
      title: 'Slot Assignments',
      epochLabel: 'Epoch $epoch',
      slotProgressLeftLabel: '$curr / $total slots',
      slotProgress: progress,
      highlightIndex: highlightIndex,
      filters: [
        SlotFilterData(
          label: 'Won Slots',
          count: wonSlotsCount,
          selected: _selected == _Filter.wonSlots,
        ),
        SlotFilterData(
          label: 'Produced',
          count: producedCount,
          selected: _selected == _Filter.produced,
        ),
        SlotFilterData(
          label: 'Missed',
          count: missedCount,
          selected: _selected == _Filter.missed,
        ),
        SlotFilterData(
          label: 'Upcoming',
          count: upcomingCount,
          selected: _selected == _Filter.upcoming,
        ),
      ],
      onFilterTap: _onFilterTap,
      items: dsItems,
      onItemTap: (index) {
        final item = filtered[index];
        context.push(
          AppRoutes.producedBlockDetails,
          extra: {
            'epoch': epoch,
            'slot': item.slot,
            'metadata': item.producedMeta,
            'slotsInEpoch': slotsInEpoch,
          },
        );
      },
      onBackTap: () => context.pop(),
    );
  }
}
