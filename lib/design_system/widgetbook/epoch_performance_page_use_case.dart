import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/epoch_performance_page.dart';

WidgetbookComponent epochPerformancePageComponent() {
  return WidgetbookComponent(
    name: 'EpochPerformance',
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
            initialValue: 0.72,
            min: 0,
            max: 1,
          );

          final checkedSlots = context.knobs.string(
            label: 'Checked Slots %',
            initialValue: '100%',
          );

          final producedBlocks = context.knobs.int.slider(
            label: 'Produced Blocks',
            initialValue: 16,
            min: 0,
            max: 30,
          );

          final missedBlocks = context.knobs.int.slider(
            label: 'Missed Blocks',
            initialValue: 0,
            min: 0,
            max: 10,
          );

          final upcomingBlocks = context.knobs.int.slider(
            label: 'Upcoming Blocks',
            initialValue: 3,
            min: 0,
            max: 10,
          );

          return Scaffold(
            body: EpochPerformancePage(
              epochLabel: 'Epoch $epochNumber',
              progress: progress,
              progressLeftLabel: '12,442 / 17,280 slots',
              progressRightLabel: '7h 14min left',
              performanceLabel: 'Epoch Performance',
              performanceValue: '95.2%',
              metrics: [
                EpochMetricData(
                  icon: Symbols.search_sharp,
                  title: 'Checked Slots',
                  subtitle: 'Evaluated 240 of 240',
                  trailingValue: checkedSlots,
                  onTap: () {},
                  showChevron: true,
                ),
                EpochMetricData(
                  icon: Symbols.check_box_sharp,
                  title: 'Produced Blocks',
                  subtitle: '$producedBlocks of 21 won slots',
                  trailingValue: '$producedBlocks',
                  onTap: producedBlocks > 0 ? () {} : null,
                  showChevron: producedBlocks > 0,
                ),
                EpochMetricData(
                  icon: Symbols.disabled_by_default_sharp,
                  title: 'Missed Blocks',
                  subtitle: '$missedBlocks of 21 won slots missed',
                  trailingValue: '$missedBlocks',
                  onTap: missedBlocks > 0 ? () {} : null,
                  showChevron: missedBlocks > 0,
                ),
                EpochMetricData(
                  icon: Symbols.schedule_sharp,
                  title: 'Upcoming Blocks',
                  subtitle: '$upcomingBlocks upcoming this epoch',
                  trailingValue: '$upcomingBlocks',
                  onTap: upcomingBlocks > 0 ? () {} : null,
                  showChevron: upcomingBlocks > 0,
                ),
              ],
              onPickEpoch: (_) {},
              maxEpoch: 200,
              selectedEpoch: epochNumber,
              onBackTap: () {},
            ),
          );
        },
      ),
    ],
  );
}
