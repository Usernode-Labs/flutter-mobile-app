import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_category_icon.dart';

WidgetbookComponent challengeCardComponent() {
  return WidgetbookComponent(
    name: 'ChallengeCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final variant = context.knobs.object.dropdown<ChallengeCardVariant>(
            label: 'Variant',
            options: ChallengeCardVariant.values,
            initialOption: ChallengeCardVariant.active,
            labelBuilder: (v) => v.name,
          );

          final category = context.knobs.object.dropdown<ChallengeCategory>(
            label: 'Category',
            options: ChallengeCategory.values,
            initialOption: ChallengeCategory.technical,
            labelBuilder: (c) => c.name,
          );

          final title = context.knobs.string(
            label: 'Title',
            initialValue: 'Run a Full Node',
          );

          final description = context.knobs.string(
            label: 'Description',
            initialValue:
                'Keep your node running and connected for the entire challenge period to earn maximum rewards.',
          );

          final dateRange = context.knobs.string(
            label: 'Date Range',
            initialValue: 'Jan 15 - Feb 15',
          );

          final rewardText = context.knobs.stringOrNull(
            label: 'Reward Text (active)',
            initialValue: 'Up to 1000 pts',
          );

          final earnedPoints = context.knobs.stringOrNull(
            label: 'Earned Points (ongoing)',
            initialValue: '10,550.1 pts',
          );

          final epochPoints = context.knobs.stringOrNull(
            label: 'Epoch Points (ongoing)',
            initialValue: '+50 pts',
          );

          final completedPoints = context.knobs.stringOrNull(
            label: 'Completed Points',
            initialValue: '500 pts',
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ChallengeCard(
              title: title,
              description: description,
              dateRange: dateRange,
              category: category,
              categoryIcon: ChallengeCategoryIcon(
                category: category,
                muted: variant == ChallengeCardVariant.missed,
              ),
              variant: variant,
              rewardText: rewardText,
              earnedPoints: earnedPoints,
              epochPoints: epochPoints,
              completedPoints: completedPoints,
            ),
          );
        },
      ),
    ],
  );
}
