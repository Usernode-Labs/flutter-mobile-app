import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_icon.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_tile.dart';

part 'challenge_category_tile.stories.g.dart';

const meta = Meta<ChallengeCategoryTile>(path: 'widgets/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    categoryIcon: Arg.fixed(
      const ChallengeCategoryIcon(category: ChallengeCategory.technical),
    ),
    categoryName: StringArg('Technical'),
    remainingCount: IntArg(3),
    completedCount: IntArg(2),
    pointsLabel: StringArg('4,525 pts'),
    challenges: Arg.fixed(const [
      ChallengeCategoryItem(title: 'Produce Blocks', isCompleted: false),
      ChallengeCategoryItem(title: 'Run SNARK Worker', isCompleted: true),
      ChallengeCategoryItem(title: 'Send zkApp Txn', isCompleted: false),
      ChallengeCategoryItem(title: 'Delegate Stake', isCompleted: true),
      ChallengeCategoryItem(title: 'Uptime Tracking', isCompleted: false),
    ]),
    initiallyExpanded: BoolArg(true),
    onExpansionChanged: Arg.fixed(null),
  ),
  scenarios: [
    _Scenario(
      name: 'Expanded',
      args: _Args.fixed(
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        challenges: const [
          ChallengeCategoryItem(title: 'Produce Blocks', isCompleted: false),
          ChallengeCategoryItem(title: 'Run SNARK Worker', isCompleted: true),
          ChallengeCategoryItem(title: 'Send zkApp Txn', isCompleted: false),
          ChallengeCategoryItem(title: 'Delegate Stake', isCompleted: true),
          ChallengeCategoryItem(title: 'Uptime Tracking', isCompleted: false),
        ],
        initiallyExpanded: true,
      ),
    ),
    _Scenario(
      name: 'Collapsed',
      args: _Args.fixed(
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        challenges: const [
          ChallengeCategoryItem(title: 'Produce Blocks', isCompleted: false),
          ChallengeCategoryItem(title: 'Run SNARK Worker', isCompleted: true),
          ChallengeCategoryItem(title: 'Send zkApp Txn', isCompleted: false),
          ChallengeCategoryItem(title: 'Delegate Stake', isCompleted: true),
          ChallengeCategoryItem(title: 'Uptime Tracking', isCompleted: false),
        ],
        initiallyExpanded: false,
      ),
    ),
    _Scenario(
      name: 'All Completed',
      args: _Args.fixed(
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        remainingCount: 0,
        completedCount: 5,
        challenges: const [
          ChallengeCategoryItem(title: 'Produce Blocks', isCompleted: true),
          ChallengeCategoryItem(title: 'Run SNARK Worker', isCompleted: true),
          ChallengeCategoryItem(title: 'Send zkApp Txn', isCompleted: true),
          ChallengeCategoryItem(title: 'Delegate Stake', isCompleted: true),
          ChallengeCategoryItem(title: 'Uptime Tracking', isCompleted: true),
        ],
      ),
    ),
    _Scenario(
      name: 'None Completed',
      args: _Args.fixed(
        categoryIcon: const ChallengeCategoryIcon(
          category: ChallengeCategory.technical,
        ),
        remainingCount: 5,
        completedCount: 0,
        challenges: const [
          ChallengeCategoryItem(title: 'Produce Blocks', isCompleted: false),
          ChallengeCategoryItem(title: 'Run SNARK Worker', isCompleted: false),
          ChallengeCategoryItem(title: 'Send zkApp Txn', isCompleted: false),
          ChallengeCategoryItem(title: 'Delegate Stake', isCompleted: false),
          ChallengeCategoryItem(title: 'Uptime Tracking', isCompleted: false),
        ],
      ),
    ),
  ],
);
