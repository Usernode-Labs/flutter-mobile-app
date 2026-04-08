import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_activity_summary.dart';

part 'challenge_activity_summary.stories.g.dart';

const meta = Meta<ChallengeActivitySummary>(path: 'widgets/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    completedCount: IntArg(5),
    missedCount: IntArg(2),
    totalCount: IntArg(10),
    onViewCompleted: Arg.fixed(() {}),
    onViewMissed: Arg.fixed(() {}),
  ),
);

final $NoChallenges = _Story(
  name: 'No Challenges',
  args: _Args(
    completedCount: IntArg(0),
    missedCount: IntArg(0),
    totalCount: IntArg(0),
    onViewCompleted: Arg.fixed(null),
    onViewMissed: Arg.fixed(null),
  ),
);
