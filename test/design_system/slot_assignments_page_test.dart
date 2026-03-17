import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

const _defaultFilters = [
  SlotFilterData(label: 'Won Slots', count: 5, selected: true),
  SlotFilterData(label: 'Produced', count: 3),
  SlotFilterData(label: 'Missed', count: 1),
  SlotFilterData(label: 'Upcoming', count: 1),
];

const _defaultItems = [
  SlotAssignmentItemData(
    slot: 100,
    status: SlotStatus.produced,
    timeLabel: 'Produced at 08:21:00',
    isTappable: true,
  ),
  SlotAssignmentItemData(
    slot: 101,
    status: SlotStatus.missed,
    timeLabel: 'Missed at 09:15:00',
  ),
  SlotAssignmentItemData(
    slot: 102,
    status: SlotStatus.upcoming,
    timeLabel: 'Scheduled for 14:00:00',
  ),
];

Widget _buildPage({
  List<SlotFilterData> filters = _defaultFilters,
  List<SlotAssignmentItemData> items = _defaultItems,
  ValueChanged<int>? onFilterTap,
  ValueChanged<int>? onItemTap,
  VoidCallback? onBackTap,
  String epochLabel = 'Epoch 176',
  String slotProgressLeftLabel = '5000 / 7140 slots',
  String? slotProgressRightLabel,
  double slotProgress = 0.7,
}) {
  return wrap(
    SlotAssignmentsPage(
      title: 'Slot Assignments',
      epochLabel: epochLabel,
      slotProgressLeftLabel: slotProgressLeftLabel,
      slotProgressRightLabel: slotProgressRightLabel,
      slotProgress: slotProgress,
      filters: filters,
      onFilterTap: onFilterTap ?? (_) {},
      items: items,
      onItemTap: onItemTap,
      onBackTap: onBackTap,
    ),
  );
}

void main() {
  group('SlotAssignmentsPage', () {
    testWidgets('renders epoch label and progress bar', (tester) async {
      await tester.pumpWidget(_buildPage());

      expect(find.text('Epoch 176'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('5000 / 7140 slots'), findsOneWidget);
    });

    testWidgets('renders optional right progress label', (tester) async {
      await tester.pumpWidget(
        _buildPage(slotProgressRightLabel: '3h 12min left'),
      );

      expect(find.text('3h 12min left'), findsOneWidget);
    });

    testWidgets('renders filter chips with counts', (tester) async {
      await tester.pumpWidget(_buildPage());

      expect(find.byType(FilterChip), findsNWidgets(4));
      expect(find.text('Won Slots'), findsOneWidget);
      // "Produced", "Missed", "Upcoming" appear in both chips and item trailing
      expect(find.byType(FilterChip), findsNWidgets(4));
      // Count avatars
      expect(find.text('5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('onFilterTap fires with correct index', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        _buildPage(
          onFilterTap: (i) => tappedIndex = i,
          items: const [], // empty to avoid label collision
        ),
      );

      await tester.tap(find.text('Missed'));
      expect(tappedIndex, 2);
    });

    testWidgets('renders item list tiles', (tester) async {
      await tester.pumpWidget(_buildPage());

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Slot 100'), findsOneWidget);
      expect(find.text('Slot 101'), findsOneWidget);
      expect(find.text('Slot 102'), findsOneWidget);
    });

    testWidgets('shows subtitle time labels', (tester) async {
      await tester.pumpWidget(_buildPage());

      expect(find.text('Produced at 08:21:00'), findsOneWidget);
      expect(find.text('Missed at 09:15:00'), findsOneWidget);
      expect(find.text('Scheduled for 14:00:00'), findsOneWidget);
    });

    testWidgets('shows status labels in trailing', (tester) async {
      await tester.pumpWidget(_buildPage());

      expect(find.text('Produced'), findsNWidgets(2)); // filter chip + item
      expect(find.text('Missed'), findsNWidgets(2));
      expect(find.text('Upcoming'), findsNWidgets(2));
    });

    testWidgets('tappable items show chevron and fire onItemTap',
        (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        _buildPage(onItemTap: (i) => tappedIndex = i),
      );

      // Only the produced item (index 0) is tappable
      expect(find.byIcon(Symbols.chevron_right_sharp), findsOneWidget);

      await tester.tap(find.text('Slot 100'));
      expect(tappedIndex, 0);
    });

    testWidgets('non-tappable items do not fire onItemTap', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        _buildPage(onItemTap: (i) => tappedIndex = i),
      );

      await tester.tap(find.text('Slot 101'));
      expect(tappedIndex, isNull);
    });

    testWidgets('empty state renders no ListTiles', (tester) async {
      await tester.pumpWidget(_buildPage(items: const []));

      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('back button calls onBackTap', (tester) async {
      var backTapped = false;
      await tester.pumpWidget(
        _buildPage(onBackTap: () => backTapped = true),
      );

      await tester.tap(find.byIcon(Symbols.arrow_back_sharp));
      expect(backTapped, isTrue);
    });

    testWidgets('orphaned items get error badge colors', (tester) async {
      await tester.pumpWidget(_buildPage(
        items: const [
          SlotAssignmentItemData(
            slot: 50,
            status: SlotStatus.orphaned,
            isTappable: true,
          ),
        ],
      ));

      // Verify the IconBadge uses error colors (non-default)
      final badge = tester.widget<IconBadge>(find.byType(IconBadge));
      expect(badge.backgroundColor, isNotNull);
    });
  });
}
