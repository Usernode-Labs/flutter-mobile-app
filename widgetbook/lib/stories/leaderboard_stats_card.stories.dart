import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/leaderboard_stats_card.dart';

part 'leaderboard_stats_card.stories.g.dart';

const meta = Meta<LeaderboardStatsCard>(path: 'widgets/data-display');

final $Default = _Story(
  args: _Args(
    totalPoints: StringArg('18,000'),
    totalPointsLabel: StringArg('TOTAL POINTS'),
    rank: StringArg('34'),
    rankLabel: StringArg('RANK'),
    distributionCounts: Arg.fixed([12, 45, 78, 120, 95, 60, 30, 15, 8, 3]),
    userBucketIndex: Arg.fixed(4),
    minScoreLabel: StringArg('0'),
    userScoreLabel: StringArg('8,000'),
    maxScoreLabel: StringArg('15,000'),
    calloutTitle: StringArg('Better than 45% of participants'),
    calloutBody: StringArg('You are in the top half of all participants'),
    bucketScoreLabels: Arg.fixed([
      '0–1,500 pts',
      '1,500–3,000 pts',
      '3,000–4,500 pts',
      '4,500–6,000 pts',
      '6,000–7,500 pts',
      '7,500–9,000 pts',
      '9,000–10,500 pts',
      '10,500–12,000 pts',
      '12,000–13,500 pts',
      '13,500–15,000 pts',
    ]),
    onBucketTapped: Arg.fixed(null),
  ),
);
