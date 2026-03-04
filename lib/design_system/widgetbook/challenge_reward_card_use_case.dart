import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_reward_card.dart';
import '../tokens/app_spacing.dart';

WidgetbookComponent challengeRewardCardComponent() {
  return WidgetbookComponent(
    name: 'ChallengeRewardCard',
    useCases: [
      WidgetbookUseCase(
        name: 'Simple',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
          );
          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '10,550.1',
          );

          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: SizedBox(
                width: 360,
                child: ChallengeRewardCard(
                  category: category,
                  totalEarned: totalEarned,
                  data: const SimpleRewardData(),
                ),
              ),
            ),
          );
        },
      ),
      WidgetbookUseCase(
        name: 'Produce Blocks',
        builder: (context) {
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final category = context.knobs.object.dropdown(
            label: 'Category',
            options: ChallengeCategory.values,
            labelBuilder: (c) => c.name,
          );
          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '4,900',
          );
          final progress = context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.85,
            min: 0,
            max: 1,
          );

          return Center(
            child: Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: SizedBox(
                width: 360,
                child: ChallengeRewardCard(
                  category: category,
                  totalEarned: totalEarned,
                  data: ProduceBlocksRewardData(
                    progressFraction: progress,
                    successRate: '98%',
                    maxPoints: '5,000',
                    totalPoints: totalEarned,
                    rankLabel: '1st',
                    rankReward: '+500',
                  ),
                  epochSectionLabel: 'This Epoch Earned',
                  epochEarned: '+50',
                  epochLabel: 'View Epoch 176',
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
