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

          final isProduceBlocks = context.knobs.boolean(
            label: 'Produce Blocks Variant',
            initialValue: true,
          );

          final ChallengeRewardData rewardData;
          if (isProduceBlocks) {
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

            final showRankLabel = context.knobs.boolean(
              label: 'Show Rank Label',
              initialValue: false,
            );

            final rankLabel = showRankLabel
                ? context.knobs.string(
                    label: 'Rank Label',
                    initialValue: '1st',
                  )
                : null;

            final rateLabel = context.knobs.string(
              label: 'Rate Label',
              initialValue: 'BLOCK RATE',
            );

            rewardData = ProduceBlocksRewardData(
              progressFraction: progressFraction,
              successRate: successRate,
              maxPoints: maxPoints,
              totalPoints: totalPoints,
              rankLabel: rankLabel,
              rankReward: rankReward,
              rateLabel: rateLabel,
            );
          } else {
            rewardData = const SimpleRewardData();
          }

          final showEpoch = context.knobs.boolean(
            label: 'Show Epoch Section',
            initialValue: true,
          );

          final epochSectionLabel = context.knobs.string(
            label: 'Epoch Section Label',
            initialValue: 'Last 24h',
          );

          final epochEarned = context.knobs.string(
            label: 'Epoch Earned',
            initialValue: '+50',
          );

          final epochLabel = context.knobs.string(
            label: 'Epoch Button Label',
            initialValue: 'View Details',
          );

          final showRewardCard = context.knobs.boolean(
            label: 'Show Reward Card',
            initialValue: true,
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

          final showBreakdown = context.knobs.boolean(
            label: 'Show Points Breakdown',
            initialValue: true,
          );

          final showCta = context.knobs.boolean(
            label: 'Show CTA Button',
            initialValue: false,
          );

          final ctaLabel = showCta
              ? context.knobs.string(
                  label: 'CTA Label',
                  initialValue: 'Take survey',
                )
              : null;

          return ChallengeDetailPage(
            title: title,
            category: category,
            dateRange: dateRange,
            rewardCard: showRewardCard
                ? ChallengeRewardCard(
                    category: category,
                    totalEarned: totalEarned,
                    data: rewardData,
                    epochSectionLabel: showEpoch ? epochSectionLabel : null,
                    epochEarned: showEpoch ? epochEarned : null,
                    epochLabel: showEpoch ? epochLabel : null,
                  )
                : null,
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
            pointsBreakdown: showBreakdown
                ? const [
                    (
                      description: 'Gave 5 kudos week 1 -> 500 pts',
                      points: '+500',
                      date: 'Jun 11, 2026',
                    ),
                    (
                      description: 'Gave 5 kudos week 2 -> 500 pts',
                      points: '+500',
                      date: 'Jun 11, 2026',
                    ),
                    (
                      description: 'Gave 5 kudos week 3 -> 500 pts',
                      points: '+500',
                      date: 'Jun 11, 2026',
                    ),
                  ]
                : const [],
            pointsBreakdownTotal: showBreakdown ? '1,500 pts' : null,
            ctaLabel: ctaLabel,
            onCtaTap: showCta ? () {} : null,
          );
        },
      ),
    ],
  );
}
