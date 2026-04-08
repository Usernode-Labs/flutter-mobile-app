import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/rank_badge.dart';

part 'rank_badge.stories.g.dart';

const meta = Meta<RankBadge>(path: 'widgets/indicators');

final $Default = _Story(args: _Args(rank: StringArg('#1')));

final $LargeRank = _Story(
  name: 'Large Rank',
  args: _Args(rank: StringArg('99')),
);
