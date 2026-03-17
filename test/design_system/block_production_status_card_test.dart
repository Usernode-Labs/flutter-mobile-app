import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'helpers/ds_test_helpers.dart';

BlockProductionStatusData _baseData({
  VoidCallback? networkOnTap,
  VoidCallback? vrfOnTap,
  VoidCallback? nextBlockOnTap,
  VoidCallback? lastProducedOnTap,
  PipelineStepStatus? missedBlocks,
}) {
  return BlockProductionStatusData(
    network: PipelineStepStatus(
      label: 'Network',
      icon: Symbols.wifi_sharp,
      trailing: const StepTrailingBadge(
        label: 'Connected',
        variant: StatusBadgeVariant.success,
      ),
      onTap: networkOnTap,
    ),
    vrf: PipelineStepStatus(
      label: 'VRF Calculation',
      icon: Symbols.casino_sharp,
      trailing: const StepTrailingBadge(
        label: 'Complete',
        variant: StatusBadgeVariant.success,
      ),
      onTap: vrfOnTap,
    ),
    nextBlock: PipelineStepStatus(
      label: 'Next Block',
      icon: Symbols.schedule_sharp,
      trailing: const StepTrailingText(text: 'in ~12 min'),
      onTap: nextBlockOnTap,
    ),
    lastProduced: PipelineStepStatus(
      label: 'Last Produced',
      icon: Symbols.check_circle_sharp,
      trailing: const StepTrailingText(text: '2 min ago'),
      onTap: lastProducedOnTap,
    ),
    missedBlocks: missedBlocks,
  );
}

void main() {
  group('BlockProductionStatusCard', () {
    testWidgets('renders 4 rows by default', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(data: _baseData()),
      ));

      expect(find.byType(ListTile), findsNWidgets(4));
      expect(find.text('Network'), findsOneWidget);
      expect(find.text('VRF Calculation'), findsOneWidget);
      expect(find.text('Next Block'), findsOneWidget);
      expect(find.text('Last Produced'), findsOneWidget);
    });

    testWidgets('renders 5 rows when missedBlocks is provided', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(
          data: _baseData(
            missedBlocks: const PipelineStepStatus(
              label: 'Missed Blocks',
              icon: Symbols.disabled_by_default_sharp,
              trailing: StepTrailingText(text: '3 blocks'),
            ),
          ),
        ),
      ));

      expect(find.byType(ListTile), findsNWidgets(5));
      expect(find.text('Missed Blocks'), findsOneWidget);
      expect(find.text('3 blocks'), findsOneWidget);
    });

    testWidgets('ListTile is tappable when onTap is provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(
          data: _baseData(networkOnTap: () => tapped = true),
        ),
      ));

      await tester.tap(find.text('Network'));
      expect(tapped, isTrue);
    });

    testWidgets('ListTile is not tappable when onTap is null', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(data: _baseData()),
      ));

      // ListTile with null onTap should not have an InkWell with an onTap
      final networkTile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Network'),
      );
      expect(networkTile.onTap, isNull);
    });

    testWidgets('shows chevron icon only for tappable rows', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(
          data: _baseData(networkOnTap: () {}),
        ),
      ));

      // Only the Network row has onTap, so only 1 chevron
      expect(find.byIcon(Symbols.chevron_right_sharp), findsOneWidget);
    });

    testWidgets('shows no chevron when no rows are tappable', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(data: _baseData()),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsNothing);
    });

    testWidgets('all rows tappable shows chevron on each', (tester) async {
      await tester.pumpWidget(wrap(
        BlockProductionStatusCard(
          data: _baseData(
            networkOnTap: () {},
            vrfOnTap: () {},
            nextBlockOnTap: () {},
            lastProducedOnTap: () {},
            missedBlocks: PipelineStepStatus(
              label: 'Missed Blocks',
              icon: Symbols.disabled_by_default_sharp,
              trailing: const StepTrailingText(text: '3 blocks'),
              onTap: () {},
            ),
          ),
        ),
      ));

      expect(find.byIcon(Symbols.chevron_right_sharp), findsNWidgets(5));
    });
  });
}
