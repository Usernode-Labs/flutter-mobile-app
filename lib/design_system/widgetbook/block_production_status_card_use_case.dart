import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/block_production_status_card.dart';
import '../src/status_badge.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent blockProductionStatusCardComponent() {
  return WidgetbookComponent(
    name: 'BlockProductionStatusCard',
    useCases: [
      _allGreen(),
      _disconnected(),
      _tappableRows(),
    ],
  );
}

WidgetbookUseCase _allGreen() {
  return WidgetbookUseCase(
    name: 'All Green',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: const BlockProductionStatusCard(
          data: BlockProductionStatusData(
            network: PipelineStepStatus(
              label: 'Network',
              icon: Symbols.wifi_sharp,
              trailing: StepTrailingBadge(
                label: 'Connected',
                variant: StatusBadgeVariant.success,
              ),
            ),
            vrf: PipelineStepStatus(
              label: 'VRF Calculation',
              icon: Symbols.casino_sharp,
              trailing: StepTrailingBadge(
                label: 'Complete',
                variant: StatusBadgeVariant.success,
              ),
            ),
            nextBlock: PipelineStepStatus(
              label: 'Next Block',
              icon: Symbols.schedule_sharp,
              trailing: StepTrailingText(text: 'in ~12 min'),
            ),
            lastProduced: PipelineStepStatus(
              label: 'Last Produced',
              icon: Symbols.check_circle_sharp,
              trailing: StepTrailingText(text: '2 min ago'),
            ),
          ),
        ),
      );
    },
  );
}

WidgetbookUseCase _disconnected() {
  return WidgetbookUseCase(
    name: 'Disconnected',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: const BlockProductionStatusCard(
          data: BlockProductionStatusData(
            network: PipelineStepStatus(
              label: 'Network',
              icon: Symbols.wifi_sharp,
              trailing: StepTrailingBadge(
                label: 'Disconnected',
                variant: StatusBadgeVariant.error,
              ),
            ),
            vrf: PipelineStepStatus(
              label: 'VRF Calculation',
              icon: Symbols.casino_sharp,
              trailing: StepTrailingBadge(
                label: 'Pending',
                variant: StatusBadgeVariant.neutral,
              ),
            ),
            nextBlock: PipelineStepStatus(
              label: 'Next Block',
              icon: Symbols.schedule_sharp,
              trailing: StepTrailingBadge(
                label: 'Waiting for VRF',
                variant: StatusBadgeVariant.neutral,
              ),
            ),
            lastProduced: PipelineStepStatus(
              label: 'Last Produced',
              icon: Symbols.check_circle_sharp,
              trailing: StepTrailingBadge(
                label: 'None yet',
                variant: StatusBadgeVariant.neutral,
              ),
            ),
          ),
        ),
      );
    },
  );
}

WidgetbookUseCase _tappableRows() {
  return WidgetbookUseCase(
    name: 'Tappable Rows',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;

      return Padding(
        padding: EdgeInsets.all(spacing.space16),
        child: BlockProductionStatusCard(
          data: BlockProductionStatusData(
            network: PipelineStepStatus(
              label: 'Network',
              icon: Symbols.wifi_sharp,
              trailing: const StepTrailingBadge(
                label: 'Connected',
                variant: StatusBadgeVariant.success,
              ),
              onTap: () {},
            ),
            vrf: PipelineStepStatus(
              label: 'VRF Calculation',
              icon: Symbols.casino_sharp,
              trailing: const StepTrailingBadge(
                label: 'Complete',
                variant: StatusBadgeVariant.success,
              ),
              onTap: () {},
            ),
            nextBlock: PipelineStepStatus(
              label: 'Next Block',
              icon: Symbols.schedule_sharp,
              trailing: const StepTrailingText(text: 'in ~12 min'),
              onTap: () {},
            ),
            lastProduced: PipelineStepStatus(
              label: 'Last Produced',
              icon: Symbols.check_circle_sharp,
              trailing: const StepTrailingText(text: '2 min ago'),
              onTap: () {},
            ),
            missedBlocks: PipelineStepStatus(
              label: 'Missed Blocks',
              icon: Symbols.disabled_by_default_sharp,
              trailing: const StepTrailingText(text: '3 blocks'),
              onTap: () {},
            ),
          ),
        ),
      );
    },
  );
}
