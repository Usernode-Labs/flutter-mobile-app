import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/slot_assignments_page.dart';

WidgetbookComponent slotAssignmentsPageComponent() {
  return WidgetbookComponent(
    name: 'SlotAssignments',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final epochNumber = context.knobs.int.slider(
            label: 'Epoch',
            initialValue: 176,
            min: 0,
            max: 200,
          );

          final progress = context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.70,
            min: 0,
            max: 1,
          );

          final itemCount = context.knobs.int.slider(
            label: 'Item Count',
            initialValue: 20,
            min: 0,
            max: 50,
          );

          return _PlaygroundBuilder(
            epochNumber: epochNumber,
            progress: progress,
            itemCount: itemCount,
          );
        },
      ),
      WidgetbookUseCase(
        name: 'All Produced',
        builder: (context) {
          final items = List.generate(
            12,
            (i) => SlotAssignmentItemData(
              slot: 5000 + i,
              status: SlotStatus.produced,
              timeLabel: 'Today, ${(8 + i).toString().padLeft(2, '0')}:21',
              isTappable: true,
            ),
          );

          return SlotAssignmentsPage(
            title: 'Slot Assignments',
            epochLabel: 'Epoch 176',
            slotProgressLeftLabel: '5000 / 7140 slots',
            slotProgressRightLabel: '3h 12min left',
            slotProgress: 0.70,
            filters: const [
              SlotFilterData(label: 'Won Slots', count: 12, selected: true),
              SlotFilterData(label: 'Produced', count: 12),
              SlotFilterData(label: 'Missed', count: 0),
              SlotFilterData(label: 'Upcoming', count: 0),
            ],
            onFilterTap: (_) {},
            items: items,
            onItemTap: (_) {},
            onBackTap: () {},
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Mixed Results',
        builder: (context) {
          final items = [
            const SlotAssignmentItemData(
              slot: 5012,
              status: SlotStatus.produced,
              timeLabel: 'Today, 14:21',
              isTappable: true,
            ),
            const SlotAssignmentItemData(
              slot: 5011,
              status: SlotStatus.produced,
              timeLabel: 'Today, 13:05',
              isTappable: true,
            ),
            const SlotAssignmentItemData(
              slot: 5010,
              status: SlotStatus.missed,
              timeLabel: 'Today, 12:42',
            ),
            const SlotAssignmentItemData(
              slot: 5009,
              status: SlotStatus.orphaned,
              timeLabel: 'Today, 11:18',
              isTappable: true,
            ),
            const SlotAssignmentItemData(
              slot: 5008,
              status: SlotStatus.produced,
              timeLabel: 'Yesterday, 23:55',
              isTappable: true,
            ),
            const SlotAssignmentItemData(
              slot: 5007,
              status: SlotStatus.upcoming,
              timeLabel: 'Today, 15:30',
            ),
            const SlotAssignmentItemData(
              slot: 5006,
              status: SlotStatus.upcoming,
              timeLabel: 'Today, 16:45',
            ),
            const SlotAssignmentItemData(
              slot: 5005,
              status: SlotStatus.notCalculated,
            ),
            const SlotAssignmentItemData(
              slot: 5004,
              status: SlotStatus.notWon,
            ),
          ];

          return SlotAssignmentsPage(
            title: 'Slot Assignments',
            epochLabel: 'Epoch 176',
            slotProgressLeftLabel: '5012 / 7140 slots',
            slotProgressRightLabel: '7h 14min left',
            slotProgress: 0.70,
            filters: const [
              SlotFilterData(label: 'Won Slots', count: 9, selected: true),
              SlotFilterData(label: 'Produced', count: 4),
              SlotFilterData(label: 'Missed', count: 1),
              SlotFilterData(label: 'Orphaned', count: 1),
              SlotFilterData(label: 'Upcoming', count: 2),
            ],
            onFilterTap: (_) {},
            items: items,
            onItemTap: (_) {},
            onBackTap: () {},
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Empty State',
        builder: (context) {
          return SlotAssignmentsPage(
            title: 'Slot Assignments',
            epochLabel: 'Epoch 176',
            slotProgressLeftLabel: '5000 / 7140 slots',
            slotProgressRightLabel: '4h 30min left',
            slotProgress: 0.70,
            filters: const [
              SlotFilterData(label: 'Won Slots', count: 21),
              SlotFilterData(label: 'Produced', count: 0, selected: true),
              SlotFilterData(label: 'Missed', count: 0),
              SlotFilterData(label: 'Upcoming', count: 0),
            ],
            onFilterTap: (_) {},
            items: const [],
            onItemTap: (_) {},
            onBackTap: () {},
          );
        },
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Stateful wrapper for the Playground use case (manages filter toggle state)
// ---------------------------------------------------------------------------

class _PlaygroundBuilder extends StatefulWidget {
  const _PlaygroundBuilder({
    required this.epochNumber,
    required this.progress,
    required this.itemCount,
  });

  final int epochNumber;
  final double progress;
  final int itemCount;

  @override
  State<_PlaygroundBuilder> createState() => _PlaygroundBuilderState();
}

class _PlaygroundBuilderState extends State<_PlaygroundBuilder> {
  int _selectedFilter = 0;

  static const _statuses = SlotStatus.values;

  List<SlotAssignmentItemData> _generateItems(int count) {
    return List.generate(count, (i) {
      final status = _statuses[i % _statuses.length];
      final hour = (8 + i) % 24;
      final minute = (i * 7) % 60;
      final timeLabel = status == SlotStatus.notCalculated ||
              status == SlotStatus.notWon
          ? null
          : '${i < 12 ? "Today" : "Mar 14"}, ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return SlotAssignmentItemData(
        slot: 5000 + count - i,
        status: status,
        timeLabel: timeLabel,
        isTappable:
            status == SlotStatus.produced || status == SlotStatus.orphaned,
      );
    });
  }

  List<SlotAssignmentItemData> _filterItems(
    List<SlotAssignmentItemData> all,
  ) {
    if (_selectedFilter == 0) return all;
    final targetStatuses = switch (_selectedFilter) {
      1 => [SlotStatus.produced],
      2 => [SlotStatus.missed],
      3 => [SlotStatus.orphaned],
      4 => [SlotStatus.upcoming],
      _ => SlotStatus.values.toList(),
    };
    return all.where((item) => targetStatuses.contains(item.status)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allItems = _generateItems(widget.itemCount);
    final filteredItems = _filterItems(allItems);

    int countByStatus(List<SlotStatus> statuses) =>
        allItems.where((i) => statuses.contains(i.status)).length;

    final filters = [
      SlotFilterData(
        label: 'Won Slots',
        count: allItems.length,
        selected: _selectedFilter == 0,
      ),
      SlotFilterData(
        label: 'Produced',
        count: countByStatus([SlotStatus.produced]),
        selected: _selectedFilter == 1,
      ),
      SlotFilterData(
        label: 'Missed',
        count: countByStatus([SlotStatus.missed]),
        selected: _selectedFilter == 2,
      ),
      SlotFilterData(
        label: 'Orphaned',
        count: countByStatus([SlotStatus.orphaned]),
        selected: _selectedFilter == 3,
      ),
      SlotFilterData(
        label: 'Upcoming',
        count: countByStatus([SlotStatus.upcoming]),
        selected: _selectedFilter == 4,
      ),
    ];

    final totalSlots = (widget.itemCount * 1.4).round();

    return SlotAssignmentsPage(
      title: 'Slot Assignments',
      epochLabel: 'Epoch ${widget.epochNumber}',
      slotProgressLeftLabel: '${widget.itemCount} / $totalSlots slots',
      slotProgressRightLabel: '3h 45min left',
      slotProgress: widget.progress,
      filters: filters,
      onFilterTap: (index) => setState(() => _selectedFilter = index),
      items: filteredItems,
      onItemTap: (_) {},
      onBackTap: () {},
    );
  }
}
