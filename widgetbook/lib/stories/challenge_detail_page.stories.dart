import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/block_production_status_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_detail_page.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_reward_card.dart';
import 'package:crypto_mobile_app/design_system/src/status_badge.dart';

part 'challenge_detail_page.stories.g.dart';

const meta = Meta<ChallengeDetailPage>(path: 'pages/challenges');

const _technicalRewardCard = ChallengeRewardCard(
  category: ChallengeCategory.technical,
  totalEarned: '6,500',
  data: ProduceBlocksRewardData(
    progressFraction: 0.82,
    successRate: '98%',
    maxPoints: '5,000',
    totalPoints: '4,900',
    rankLabel: '2nd',
    rankReward: '+500',
    firstBlockReward: '+250',
    successReward: '+1,000',
  ),
  epochSectionLabel: 'This Epoch Earned',
  epochEarned: '+50',
  epochLabel: 'View Details',
);

const _communityRewardCard = ChallengeRewardCard(
  category: ChallengeCategory.community,
  totalEarned: '3,000',
  data: SimpleRewardData(),
);

const _flashRewardCard = ChallengeRewardCard(
  category: ChallengeCategory.flash,
  totalEarned: '1,500',
  data: SimpleRewardData(),
);

const _productionStatusSection = BlockProductionStatusCard(
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
);

final $Default = _Story(
  args: _Args(
    title: StringArg('Produce Every Block'),
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    dateRange: StringArg('Technical \u00b7 Jan 12 \u2013 Jan 30'),
    rewardCard: Arg.fixed(_technicalRewardCard),
    statusSection: Arg.fixed(null),
    sections: Arg.fixed([
      (
        title: 'Why',
        body:
            'Block production secures the network. Consistent producers keep the chain healthy and decentralised.',
      ),
      (
        title: 'Task',
        body:
            'Produce every block you are assigned during the challenge period. Missed blocks reduce your score.',
      ),
      (
        title: 'Requirements',
        body:
            'You must be an active block producer with at least 1,000 MINA staked.',
      ),
    ]),
    totalRewardHeading: StringArg('Total Reward Up to 6,500 pts'),
    totalRewardBody: StringArg(
      'Base reward (1,000 pts) + bonus per produced block (up to 5,500 pts).',
    ),
    onBackTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Technical',
      args: _Args.fixed(
        title: 'Produce Every Block',
        category: ChallengeCategory.technical,
        dateRange: 'Technical \u00b7 Jan 12 \u2013 Jan 30',
        rewardCard: _technicalRewardCard,
        sections: [
          (
            title: 'Why',
            body:
                'Block production secures the network. Consistent producers keep the chain healthy and decentralised.',
          ),
          (
            title: 'Task',
            body:
                'Produce every block you are assigned during the challenge period. Missed blocks reduce your score.',
          ),
          (
            title: 'Requirements',
            body:
                'You must be an active block producer with at least 1,000 MINA staked.',
          ),
        ],
        totalRewardHeading: 'Total Reward Up to 6,500 pts',
        totalRewardBody:
            'Base reward (1,000 pts) + bonus per produced block (up to 5,500 pts).',
        onBackTap: () {},
      ),
    ),
    _Scenario(
      name: 'Community',
      args: _Args.fixed(
        title: 'Community Engagement',
        category: ChallengeCategory.community,
        dateRange: 'Community \u00b7 Feb 1 \u2013 Feb 28',
        rewardCard: _communityRewardCard,
        sections: [
          (
            title: 'Why',
            body:
                'Community support helps new operators stay online and understand the network.',
          ),
          (
            title: 'Task',
            body:
                'Answer questions, share useful feedback, and participate in weekly discussions.',
          ),
        ],
        totalRewardHeading: 'Total Reward Up to 3,000 pts',
        totalRewardBody:
            'Earn points from verified participation across the challenge period.',
        onBackTap: () {},
      ),
    ),
    _Scenario(
      name: 'Flash',
      args: _Args.fixed(
        title: 'Flash Challenge',
        category: ChallengeCategory.flash,
        dateRange: 'Flash \u00b7 Mar 15',
        rewardCard: _flashRewardCard,
        sections: [
          (
            title: 'Task',
            body:
                'Complete the one-day verification task before the flash window closes.',
          ),
          (
            title: 'Timing',
            body: 'Submissions are counted only while the challenge is active.',
          ),
        ],
        totalRewardHeading: 'Total Reward 1,500 pts',
        totalRewardBody:
            'A fixed reward is granted after successful completion.',
        onBackTap: () {},
      ),
    ),
  ],
);

final $WithStatusSection = _Story(
  name: 'With Status Section',
  args: _Args(
    title: StringArg('Produce Blocks'),
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    dateRange: StringArg('Technical \u00b7 Mar 1 \u2013 Mar 31'),
    rewardCard: Arg.fixed(_technicalRewardCard),
    statusSection: Arg.fixed(_productionStatusSection),
    sections: Arg.fixed([
      (title: 'Task', body: 'Produce as many blocks as you can this epoch.'),
    ]),
    totalRewardHeading: Arg.fixed(null),
    totalRewardBody: Arg.fixed(null),
    onBackTap: Arg.fixed(() {}),
  ),
);

final $Minimal = _Story(
  name: 'Minimal',
  args: _Args(
    title: StringArg('Community Engagement'),
    category: EnumArg(
      ChallengeCategory.community,
      values: ChallengeCategory.values,
    ),
    dateRange: StringArg('Community \u00b7 Feb 1 \u2013 Feb 28'),
    rewardCard: Arg.fixed(null),
    statusSection: Arg.fixed(null),
    sections: Arg.fixed([
      (
        title: 'Description',
        body: 'Participate in community discussions and earn points.',
      ),
    ]),
    totalRewardHeading: Arg.fixed(null),
    totalRewardBody: Arg.fixed(null),
    onBackTap: Arg.fixed(null),
  ),
);
