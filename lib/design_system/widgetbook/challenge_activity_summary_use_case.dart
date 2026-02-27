import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_activity_summary.dart';

WidgetbookComponent challengeActivitySummaryComponent() {
  return WidgetbookComponent(
    name: 'ChallengeActivitySummary',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final completedCount = context.knobs.double
              .slider(
                label: 'Completed Count',
                initialValue: 5,
                min: 0,
                max: 50,
              )
              .toInt();

          final missedCount = context.knobs.double
              .slider(
                label: 'Missed Count',
                initialValue: 2,
                min: 0,
                max: 50,
              )
              .toInt();

          final totalCount = context.knobs.double
              .slider(
                label: 'Total Count',
                initialValue: 10,
                min: 0,
                max: 100,
              )
              .toInt();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ChallengeActivitySummary(
              completedCount: completedCount,
              missedCount: missedCount,
              totalCount: totalCount,
              onViewCompleted: completedCount > 0 ? () {} : null,
              onViewMissed: missedCount > 0 ? () {} : null,
            ),
          );
        },
      ),
    ],
  );
}
