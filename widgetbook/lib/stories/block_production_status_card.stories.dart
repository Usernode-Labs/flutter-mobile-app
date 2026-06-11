import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/block_production_status_card.dart';
import 'package:crypto_mobile_app/design_system/src/status_badge.dart';

part 'block_production_status_card.stories.g.dart';

const meta = Meta<BlockProductionStatusCard>(path: 'widgets/challenges');

final $Default = _Story(
  args: _Args(
    data: Arg.fixed(
      const BlockProductionStatusData(
        network: PipelineStepStatus(
          label: 'Network',
          icon: Symbols.wifi_sharp,
          trailing: StepTrailingBadge(
            label: 'Connected',
            variant: StatusBadgeVariant.success,
          ),
        ),
        vrf: PipelineStepStatus(
          label: 'VRF Evaluation',
          icon: Symbols.key_sharp,
          trailing: StepTrailingBadge(
            label: 'Ready',
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
  ),
  scenarios: [
    _Scenario(
      name: 'All Success',
      args: _Args(
        data: Arg.fixed(
          const BlockProductionStatusData(
            network: PipelineStepStatus(
              label: 'Network',
              icon: Symbols.wifi_sharp,
              trailing: StepTrailingBadge(
                label: 'Connected',
                variant: StatusBadgeVariant.success,
              ),
            ),
            vrf: PipelineStepStatus(
              label: 'VRF Evaluation',
              icon: Symbols.key_sharp,
              trailing: StepTrailingBadge(
                label: 'Ready',
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
      ),
    ),
    _Scenario(
      name: 'With Missed Blocks',
      args: _Args(
        data: Arg.fixed(
          const BlockProductionStatusData(
            network: PipelineStepStatus(
              label: 'Network',
              icon: Symbols.wifi_sharp,
              trailing: StepTrailingBadge(
                label: 'Connected',
                variant: StatusBadgeVariant.success,
              ),
            ),
            vrf: PipelineStepStatus(
              label: 'VRF Evaluation',
              icon: Symbols.key_sharp,
              trailing: StepTrailingBadge(
                label: 'Pending',
                variant: StatusBadgeVariant.warning,
              ),
            ),
            nextBlock: PipelineStepStatus(
              label: 'Next Block',
              icon: Symbols.schedule_sharp,
              trailing: StepTrailingText(text: 'in ~45 min'),
            ),
            lastProduced: PipelineStepStatus(
              label: 'Last Produced',
              icon: Symbols.check_circle_sharp,
              trailing: StepTrailingText(text: '1h ago'),
            ),
            missedBlocks: PipelineStepStatus(
              label: 'Missed Blocks',
              icon: Symbols.warning_sharp,
              trailing: StepTrailingBadge(
                label: '3 missed',
                variant: StatusBadgeVariant.error,
              ),
            ),
          ),
        ),
      ),
    ),
  ],
);

final $WithMissedBlocks = _Story(
  name: 'With Missed Blocks',
  args: _Args(
    data: Arg.fixed(
      const BlockProductionStatusData(
        network: PipelineStepStatus(
          label: 'Network',
          icon: Symbols.wifi_sharp,
          trailing: StepTrailingBadge(
            label: 'Connected',
            variant: StatusBadgeVariant.success,
          ),
        ),
        vrf: PipelineStepStatus(
          label: 'VRF Evaluation',
          icon: Symbols.key_sharp,
          trailing: StepTrailingBadge(
            label: 'Pending',
            variant: StatusBadgeVariant.warning,
          ),
        ),
        nextBlock: PipelineStepStatus(
          label: 'Next Block',
          icon: Symbols.schedule_sharp,
          trailing: StepTrailingText(text: 'in ~45 min'),
        ),
        lastProduced: PipelineStepStatus(
          label: 'Last Produced',
          icon: Symbols.check_circle_sharp,
          trailing: StepTrailingText(text: '1h ago'),
        ),
        missedBlocks: PipelineStepStatus(
          label: 'Missed Blocks',
          icon: Symbols.warning_sharp,
          trailing: StepTrailingBadge(
            label: '3 missed',
            variant: StatusBadgeVariant.error,
          ),
        ),
      ),
    ),
  ),
);
