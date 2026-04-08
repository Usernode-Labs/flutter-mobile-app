import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_detail_page.dart';

part 'challenge_detail_page.stories.g.dart';

const meta = Meta<ChallengeDetailPage>(path: 'pages/challenges');

final $Default = _Story(
  args: _Args(
    title: StringArg('Produce Every Block'),
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    dateRange: StringArg('Technical \u00b7 Jan 12 \u2013 Jan 30'),
    rewardCard: Arg.fixed(
      const Card(
        child: ListTile(
          title: Text('Reward'),
          subtitle: Text('Up to 6,500 pts'),
        ),
      ),
    ),
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
    rewardCard: Arg.fixed(
      const Card(
        child: ListTile(
          title: Text('Reward'),
          subtitle: Text('Up to 5,000 pts'),
        ),
      ),
    ),
    statusSection: Arg.fixed(
      const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle, color: Colors.green),
          title: Text('Block Production Active'),
          subtitle: Text('12 / 15 blocks produced'),
        ),
      ),
    ),
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
