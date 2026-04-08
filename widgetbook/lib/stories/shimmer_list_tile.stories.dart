import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/shimmer_list_tile.dart';

part 'shimmer_list_tile.stories.g.dart';

const meta = Meta<ShimmerListTile>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(isThreeLine: BoolArg(true), hasTrailing: BoolArg(true)),
);

final $TwoLine = _Story(
  name: 'Two Line',
  args: _Args(isThreeLine: BoolArg(false), hasTrailing: BoolArg(true)),
);

final $NoTrailing = _Story(
  name: 'No Trailing',
  args: _Args(isThreeLine: BoolArg(true), hasTrailing: BoolArg(false)),
);
