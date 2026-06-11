import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/shimmer_list_tile.dart';

part 'shimmer_list_tile.stories.g.dart';

const meta = Meta<ShimmerListTile>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(isThreeLine: BoolArg(true), hasTrailing: BoolArg(true)),
  scenarios: [
    _Scenario(
      name: 'Three line with trailing',
      args: _Args.fixed(isThreeLine: true, hasTrailing: true),
    ),
    _Scenario(
      name: 'Two line with trailing',
      args: _Args.fixed(isThreeLine: false, hasTrailing: true),
    ),
    _Scenario(
      name: 'Three line no trailing',
      args: _Args.fixed(isThreeLine: true, hasTrailing: false),
    ),
    _Scenario(
      name: 'Two line no trailing',
      args: _Args.fixed(isThreeLine: false, hasTrailing: false),
    ),
  ],
);

final $TwoLine = _Story(
  name: 'Two Line',
  args: _Args(isThreeLine: BoolArg(false), hasTrailing: BoolArg(true)),
);

final $NoTrailing = _Story(
  name: 'No Trailing',
  args: _Args(isThreeLine: BoolArg(true), hasTrailing: BoolArg(false)),
);
