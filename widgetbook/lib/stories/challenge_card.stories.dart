import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_icon.dart';

part 'challenge_card.stories.g.dart';

const meta = Meta<ChallengeCard>(path: 'live app/widgets/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    title: StringArg('Produce Blocks'),
    description: StringArg('Produce as many blocks as you can this epoch.'),
    dateRange: StringArg('Mar 1 – Mar 31'),
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(category: ChallengeCategory.technical),
    ),
    variant: EnumArg(
      ChallengeCardVariant.active,
      values: ChallengeCardVariant.values,
    ),
    rewardText: StringArg('Up to 5,000 pts'),
    onTap: Arg.fixed(() {}),
  ),
  scenarios: [
    _Scenario(
      name: 'Active / Technical',
      args: _Args.fixed(
        title: 'Produce Blocks',
        description: 'Produce as many blocks as you can this epoch.',
        dateRange: 'Mar 1 – Mar 31',
        category: ChallengeCategory.technical,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        variant: ChallengeCardVariant.active,
        rewardText: 'Up to 5,000 pts',
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Active / Community',
      args: _Args.fixed(
        title: 'Community Sprint',
        description: 'Help new node operators and share useful feedback.',
        dateRange: 'Feb 1 – Feb 28',
        category: ChallengeCategory.community,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.community,
        ),
        variant: ChallengeCardVariant.active,
        rewardText: 'Up to 3,000 pts',
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Active / Flash',
      args: _Args.fixed(
        title: 'Flash Challenge',
        description: 'Complete a quick network task within 24 hours.',
        dateRange: 'Mar 15',
        category: ChallengeCategory.flash,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.flash,
        ),
        variant: ChallengeCardVariant.active,
        rewardText: '1,500 pts',
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Ongoing / Technical',
      args: _Args.fixed(
        title: 'Produce Blocks',
        description: 'Keep producing blocks to earn more points.',
        dateRange: 'Mar 1 – Mar 31',
        category: ChallengeCategory.technical,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        variant: ChallengeCardVariant.ongoing,
        earnedPoints: '2,450 pts',
        epochPoints: '500 pts',
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Completed / Community',
      args: _Args.fixed(
        title: 'Community Engagement',
        description: 'Participate in community discussions.',
        dateRange: 'Feb 1 – Feb 28',
        category: ChallengeCategory.community,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.community,
        ),
        variant: ChallengeCardVariant.completed,
        completedPoints: '+4,525 pts',
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Missed / Flash',
      args: _Args.fixed(
        title: 'Flash Challenge',
        description: 'Complete a quick task within 24 hours.',
        dateRange: 'Mar 15',
        category: ChallengeCategory.flash,
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.flash,
          muted: true,
        ),
        variant: ChallengeCardVariant.missed,
        completedPoints: '0 pts',
        onTap: () {},
      ),
    ),
  ],
);

final $Ongoing = _Story(
  name: 'Ongoing',
  args: _Args(
    title: StringArg('Produce Blocks'),
    description: StringArg('Keep producing blocks to earn more points.'),
    dateRange: StringArg('Mar 1 – Mar 31'),
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(category: ChallengeCategory.technical),
    ),
    variant: EnumArg(
      ChallengeCardVariant.ongoing,
      values: ChallengeCardVariant.values,
    ),
    earnedPoints: StringArg('2,450 pts'),
    epochPoints: StringArg('500 pts'),
    onTap: Arg.fixed(() {}),
  ),
);

final $Completed = _Story(
  name: 'Completed',
  args: _Args(
    title: StringArg('Community Engagement'),
    description: StringArg('Participate in community discussions.'),
    dateRange: StringArg('Feb 1 – Feb 28'),
    category: EnumArg(
      ChallengeCategory.community,
      values: ChallengeCategory.values,
    ),
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(category: ChallengeCategory.community),
    ),
    variant: EnumArg(
      ChallengeCardVariant.completed,
      values: ChallengeCardVariant.values,
    ),
    completedPoints: StringArg('+4,525 pts'),
    onTap: Arg.fixed(() {}),
  ),
);

final $Missed = _Story(
  name: 'Missed',
  args: _Args(
    title: StringArg('Flash Challenge'),
    description: StringArg('Complete a quick task within 24 hours.'),
    dateRange: StringArg('Mar 15'),
    category: EnumArg(
      ChallengeCategory.flash,
      values: ChallengeCategory.values,
    ),
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(
        category: ChallengeCategory.flash,
        muted: true,
      ),
    ),
    variant: EnumArg(
      ChallengeCardVariant.missed,
      values: ChallengeCardVariant.values,
    ),
    completedPoints: StringArg('0 pts'),
    onTap: Arg.fixed(() {}),
  ),
);
