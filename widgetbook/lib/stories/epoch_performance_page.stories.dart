import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/epoch_performance_page.dart';

part 'epoch_performance_page.stories.g.dart';

const meta = Meta<EpochPerformancePage>(path: 'live app/pages/performance');

final $Default = _Story(
  args: _Args(
    epochLabel: StringArg('Epoch 176'),
    progress: DoubleArg(
      0.69,
      style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    progressLeftLabel: StringArg('12,000 / 17,280 slots'),
    progressRightLabel: StringArg('7h 14min left'),
    performanceLabel: StringArg('Epoch Performance'),
    performanceValue: StringArg('95.2%'),
    metrics: Arg.fixed([
      EpochMetricData(
        icon: Symbols.check_circle_sharp,
        title: 'Checked Slots',
        subtitle: '12,000 of 17,280',
        trailingValue: '69.4%',
      ),
      EpochMetricData(
        icon: Symbols.deployed_code_sharp,
        title: 'Produced Blocks',
        subtitle: '8 of 8 won',
        trailingValue: '100%',
      ),
      EpochMetricData(
        icon: Symbols.cancel_sharp,
        title: 'Missed Blocks',
        subtitle: '0 of 8 won',
        trailingValue: '0',
      ),
      EpochMetricData(
        icon: Symbols.schedule_sharp,
        title: 'Upcoming',
        subtitle: '3 slots remaining',
        trailingValue: '3',
        showChevron: true,
        onTap: () {},
      ),
    ]),
    onPickEpoch: Arg.fixed((int epoch) {}),
    maxEpoch: Arg.fixed(200),
    selectedEpoch: Arg.fixed(176),
    epochScoreLookup: Arg.fixed((int epoch) => '${90 + (epoch % 10)}%'),
    onBackTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Default',
      args: _Args.fixed(
        epochLabel: 'Epoch 176',
        performanceValue: '95.2%',
        metrics: [
          EpochMetricData(
            icon: Symbols.check_circle_sharp,
            title: 'Checked Slots',
            subtitle: '12,000 of 17,280',
            trailingValue: '69.4%',
          ),
          EpochMetricData(
            icon: Symbols.deployed_code_sharp,
            title: 'Produced Blocks',
            subtitle: '8 of 8 won',
            trailingValue: '100%',
          ),
        ],
        onPickEpoch: (int epoch) {},
      ),
    ),
  ],
);

final $EarlyEpoch = _Story(
  name: 'Early Epoch',
  args: _Args(
    epochLabel: StringArg('Epoch 2'),
    progress: DoubleArg(
      0.15,
      style: SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    progressLeftLabel: StringArg('2,592 / 17,280 slots'),
    progressRightLabel: StringArg('20h 10min left'),
    performanceLabel: StringArg('Epoch Performance'),
    performanceValue: StringArg('50.0%'),
    metrics: Arg.fixed([
      EpochMetricData(
        icon: Symbols.check_circle_sharp,
        title: 'Checked Slots',
        subtitle: '2,592 of 17,280',
        trailingValue: '15.0%',
      ),
      EpochMetricData(
        icon: Symbols.deployed_code_sharp,
        title: 'Produced Blocks',
        subtitle: '1 of 2 won',
        trailingValue: '50%',
      ),
      EpochMetricData(
        icon: Symbols.cancel_sharp,
        title: 'Missed Blocks',
        subtitle: '1 of 2 won',
        trailingValue: '1',
      ),
    ]),
    onPickEpoch: Arg.fixed((int epoch) {}),
    maxEpoch: Arg.fixed(2),
    selectedEpoch: Arg.fixed(2),
    epochScoreLookup: Arg.fixed(null),
    onBackTap: Arg.fixed(null),
  ),
);
