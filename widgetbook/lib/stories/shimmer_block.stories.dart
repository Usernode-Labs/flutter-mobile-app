import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/shimmer_block.dart';

part 'shimmer_block.stories.g.dart';

const meta = Meta<ShimmerBlock>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(width: DoubleArg(200), height: DoubleArg(20)),
);

final $Large = _Story(
  name: 'Large',
  args: _Args(width: DoubleArg(300), height: DoubleArg(48)),
);

final $Square = _Story(
  name: 'Square',
  args: _Args(width: DoubleArg(80), height: DoubleArg(80)),
);
