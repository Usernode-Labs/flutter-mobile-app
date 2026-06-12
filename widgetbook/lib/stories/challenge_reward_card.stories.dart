import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_reward_card.dart';

part 'challenge_reward_card.stories.g.dart';

const meta = Meta<ChallengeRewardCard>(path: 'live app/widgets/challenges');

final $Simple = _Story(
  name: 'Simple',
  args: _Args(
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    totalEarned: StringArg('4,525'),
    data: Arg.fixed(const SimpleRewardData()),
  ),
  scenarios: [
    _Scenario(
      name: 'Technical',
      args: _Args.fixed(
        data: const SimpleRewardData(),
        category: ChallengeCategory.technical,
      ),
    ),
    _Scenario(
      name: 'Community',
      args: _Args.fixed(
        data: const SimpleRewardData(),
        category: ChallengeCategory.community,
      ),
    ),
    _Scenario(
      name: 'Flash',
      args: _Args.fixed(
        data: const SimpleRewardData(),
        category: ChallengeCategory.flash,
      ),
    ),
  ],
);

final $ProduceBlocks = _Story(
  name: 'Produce Blocks',
  args: _Args(
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    totalEarned: StringArg('10,550.1'),
    data: Arg.fixed(
      const ProduceBlocksRewardData(
        progressFraction: 0.82,
        successRate: '98%',
        maxPoints: '5,000',
        totalPoints: '4,900',
        rankLabel: '2nd',
        rankReward: '+500',
        extraPoints: '+840',
        firstBlockReward: '+250',
        successReward: '+1,000',
      ),
    ),
    epochSectionLabel: StringArg('This Epoch Earned'),
    epochEarned: StringArg('+50'),
    epochLabel: StringArg('View Details'),
    onEpochTap: Arg.fixed(() {}),
  ),
);

final $Community = _Story(
  name: 'Community',
  args: _Args(
    category: EnumArg(
      ChallengeCategory.community,
      values: ChallengeCategory.values,
    ),
    totalEarned: StringArg('2,100'),
    data: Arg.fixed(const SimpleRewardData()),
    epochEarned: StringArg('+30'),
    epochLabel: StringArg('View Details'),
    onEpochTap: Arg.fixed(() {}),
  ),
);
