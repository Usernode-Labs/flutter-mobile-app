import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/challenge_card.dart';
import '../src/challenge_detail_page.dart';
import '../src/challenge_reward_card.dart';

WidgetbookComponent challengeDetailPageComponent() {
  return WidgetbookComponent(
    name: 'ChallengeDetail',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final category = context.knobs.object.dropdown<ChallengeCategory>(
            label: 'Category',
            options: ChallengeCategory.values,
            initialOption: ChallengeCategory.technical,
            labelBuilder: (c) => c.name,
          );

          final title = context.knobs.string(
            label: 'Title',
            initialValue: 'Produce Every Block',
          );

          final dateRange = context.knobs.string(
            label: 'Date Range',
            initialValue: 'Technical · Jan 12 - Jan 30',
          );

          final totalEarned = context.knobs.string(
            label: 'Total Earned',
            initialValue: '10,550.1',
          );

          final progressFraction = context.knobs.double.slider(
            label: 'Progress',
            initialValue: 0.98,
            min: 0,
            max: 1,
          );

          final successRate = context.knobs.string(
            label: 'Success Rate',
            initialValue: '98%',
          );

          final maxPoints = context.knobs.string(
            label: 'Max Points',
            initialValue: '5,000',
          );

          final totalPoints = context.knobs.string(
            label: 'Total Points',
            initialValue: '4,900',
          );

          final rankReward = context.knobs.string(
            label: 'Rank Reward',
            initialValue: '+0',
          );

          final showEpoch = context.knobs.boolean(
            label: 'Show Epoch Section',
            initialValue: true,
          );

          final epochEarned = context.knobs.string(
            label: 'Epoch Earned',
            initialValue: '+50',
          );

          final epochLabel = context.knobs.string(
            label: 'Epoch Button Label',
            initialValue: 'View Epoch 176',
          );

          final totalRewardHeading = context.knobs.string(
            label: 'Total Reward Heading',
            initialValue: 'Total Reward Up to 6,500 pts',
          );

          final totalRewardBody = context.knobs.string(
            label: 'Total Reward Body',
            initialValue:
                'Base reward: up to 5,000 pts based on success rate.\nRank bonus: up to 1,500 pts for top 3 producers.',
          );

          return Scaffold(
            body: ChallengeDetailPage(
              title: title,
              category: category,
              dateRange: dateRange,
              rewardCard: ChallengeRewardCard(
                category: category,
                totalEarned: totalEarned,
                progressFraction: progressFraction,
                successRate: successRate,
                maxPoints: maxPoints,
                totalPoints: totalPoints,
                rankReward: rankReward,
                epochEarned: showEpoch ? epochEarned : null,
                epochLabel: showEpoch ? epochLabel : null,
              ),
              sections: const [
                (
                  title: 'The Why',
                  body:
                      'Your score is based on how reliably your node produces blocks when assigned. This measures your contribution to network liveness and security.',
                ),
                (
                  title: 'Task',
                  body:
                      'Discover block assignments via the Explorer, and produce as many as you can. Your node must be online and synced to receive assignments.',
                ),
                (
                  title: 'Requirements',
                  body:
                      'Your score is based on the ratio of blocks produced vs blocks assigned. A node that produces 98 out of 100 assigned blocks gets a 98% success rate.',
                ),
              ],
              totalRewardHeading: totalRewardHeading,
              totalRewardBody: totalRewardBody,
            ),
          );
        },
      ),
    ],
  );
}
