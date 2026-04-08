import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_event_group.dart';

part 'challenge_event_group.stories.g.dart';

const meta = Meta<ChallengeEventGroup>(path: 'widgets/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    eventName: StringArg('Block Production'),
    dateRange: StringArg('Mar 1 – Mar 31'),
    pointsLabel: StringArg('6,500 pts'),
    challenges: Arg.fixed(const [
      ChallengeEventItem(
        title: 'Produce 10 Blocks',
        category: ChallengeCategory.technical,
        variant: ChallengeCardVariant.completed,
        earnedPoints: '2,500 pts',
      ),
      ChallengeEventItem(
        title: 'Produce 50 Blocks',
        category: ChallengeCategory.technical,
        variant: ChallengeCardVariant.ongoing,
        earnedPoints: '1,200 pts',
      ),
      ChallengeEventItem(
        title: 'First Block Bonus',
        category: ChallengeCategory.flash,
        variant: ChallengeCardVariant.missed,
        earnedPoints: '0 pts',
      ),
    ]),
  ),
);
