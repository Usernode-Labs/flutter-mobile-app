import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/shimmer_block.dart';

part 'shimmer_block.stories.g.dart';

const meta = Meta<ShimmerBlock>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(width: DoubleArg(200), height: DoubleArg(20)),
  scenarios: [
    _Scenario(
      name: 'Small text placeholder',
      args: _Args.fixed(width: 200, height: 20),
    ),
    _Scenario(
      name: 'Large block',
      args: _Args.fixed(width: 300, height: 48),
    ),
    _Scenario(
      name: 'Square avatar',
      args: _Args.fixed(width: 80, height: 80),
    ),
  ],
);

final $Large = _Story(
  name: 'Large',
  args: _Args(width: DoubleArg(300), height: DoubleArg(48)),
);

final $Square = _Story(
  name: 'Square',
  args: _Args(width: DoubleArg(80), height: DoubleArg(80)),
);
