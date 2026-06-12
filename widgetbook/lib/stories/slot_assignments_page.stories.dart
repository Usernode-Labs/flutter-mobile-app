import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/slot_assignments_page.dart';

part 'slot_assignments_page.stories.g.dart';

const meta = Meta<SlotAssignmentsPage>(path: 'live app/pages/performance');

final $Default = _Story(
  args: _Args(
    title: StringArg('Slot Assignments'),
    epochLabel: StringArg('Epoch 176'),
    slotProgressLeftLabel: StringArg('5,000 / 7,140 slots'),
    slotProgress: DoubleArg(
      0.70,
      style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    slotProgressRightLabel: StringArg('7h 14min left'),
    filters: Arg.fixed([
      const SlotFilterData(label: 'All', count: 24, selected: true),
      const SlotFilterData(label: 'Produced', count: 18),
      const SlotFilterData(label: 'Missed', count: 2),
      const SlotFilterData(label: 'Upcoming', count: 4),
    ]),
    onFilterTap: Arg.fixed((int index) {}),
    items: Arg.fixed([
      const SlotAssignmentItemData(
        slot: 7140,
        status: SlotStatus.upcoming,
        timeLabel: 'Today, 18:45',
      ),
      const SlotAssignmentItemData(
        slot: 7139,
        status: SlotStatus.upcoming,
        timeLabel: 'Today, 18:30',
      ),
      const SlotAssignmentItemData(
        slot: 7020,
        status: SlotStatus.produced,
        timeLabel: 'Today, 14:12',
        isTappable: true,
      ),
      const SlotAssignmentItemData(
        slot: 6800,
        status: SlotStatus.produced,
        timeLabel: 'Today, 08:21',
        isTappable: true,
      ),
      const SlotAssignmentItemData(
        slot: 6500,
        status: SlotStatus.missed,
        timeLabel: 'Yesterday, 22:10',
      ),
      const SlotAssignmentItemData(
        slot: 6200,
        status: SlotStatus.orphaned,
        timeLabel: 'Yesterday, 16:05',
        isTappable: true,
      ),
      const SlotAssignmentItemData(
        slot: 5900,
        status: SlotStatus.produced,
        timeLabel: 'Yesterday, 10:30',
        isTappable: true,
      ),
      const SlotAssignmentItemData(slot: 5500, status: SlotStatus.notWon),
      const SlotAssignmentItemData(
        slot: 5200,
        status: SlotStatus.notCalculated,
      ),
    ]),
    onItemTap: Arg.fixed((int index) {}),
    onBackTap: Arg.fixed(() {}),
    highlightIndex: Arg.fixed(null),
  ),
  scenarios: [
    _Scenario(
      name: 'Default',
      args: _Args.fixed(
        title: 'Slot Assignments',
        epochLabel: 'Epoch 176',
        filters: const [
          SlotFilterData(label: 'All', count: 24, selected: true),
          SlotFilterData(label: 'Produced', count: 18),
          SlotFilterData(label: 'Missed', count: 2),
          SlotFilterData(label: 'Upcoming', count: 4),
        ],
        onFilterTap: (int index) {},
        items: const [
          SlotAssignmentItemData(
            slot: 7140,
            status: SlotStatus.upcoming,
            timeLabel: 'Today, 18:45',
          ),
          SlotAssignmentItemData(
            slot: 7020,
            status: SlotStatus.produced,
            timeLabel: 'Today, 14:12',
            isTappable: true,
          ),
        ],
      ),
    ),
  ],
);

final $WithHighlight = _Story(
  name: 'With Highlight',
  args: _Args(
    title: StringArg('Slot Assignments'),
    epochLabel: StringArg('Epoch 176'),
    slotProgressLeftLabel: StringArg('5,000 / 7,140 slots'),
    slotProgress: DoubleArg(
      0.70,
      style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    slotProgressRightLabel: Arg.fixed(null),
    filters: Arg.fixed([
      const SlotFilterData(label: 'All', count: 3, selected: true),
      const SlotFilterData(label: 'Produced', count: 2),
      const SlotFilterData(label: 'Upcoming', count: 1),
    ]),
    onFilterTap: Arg.fixed((int index) {}),
    items: Arg.fixed([
      const SlotAssignmentItemData(
        slot: 7140,
        status: SlotStatus.upcoming,
        timeLabel: 'Today, 18:45',
      ),
      const SlotAssignmentItemData(
        slot: 7020,
        status: SlotStatus.produced,
        timeLabel: 'Today, 14:12',
        isTappable: true,
      ),
      const SlotAssignmentItemData(
        slot: 6800,
        status: SlotStatus.produced,
        timeLabel: 'Today, 08:21',
        isTappable: true,
      ),
    ]),
    onItemTap: Arg.fixed((int index) {}),
    onBackTap: Arg.fixed(() {}),
    highlightIndex: Arg.fixed(0),
  ),
);

final $Empty = _Story(
  name: 'Empty',
  args: _Args(
    title: StringArg('Slot Assignments'),
    epochLabel: StringArg('Epoch 1'),
    slotProgressLeftLabel: StringArg('0 / 7,140 slots'),
    slotProgress: DoubleArg(
      0.0,
      style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    slotProgressRightLabel: StringArg('24h left'),
    filters: Arg.fixed([
      const SlotFilterData(label: 'All', count: 0, selected: true),
    ]),
    onFilterTap: Arg.fixed((int index) {}),
    items: Arg.fixed(<SlotAssignmentItemData>[]),
    onItemTap: Arg.fixed(null),
    onBackTap: Arg.fixed(() {}),
    highlightIndex: Arg.fixed(null),
  ),
);
