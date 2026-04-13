import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/icon_badge.dart';

part 'icon_badge.stories.g.dart';

const meta = Meta<IconBadge>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(icon: Arg.fixed(Symbols.swap_horiz_sharp)),
  scenarios: [
    _Scenario(
      name: 'Default Icon',
      args: _Args(icon: Arg.fixed(Symbols.swap_horiz_sharp)),
    ),
    _Scenario(
      name: 'Bolt Icon',
      args: _Args(icon: Arg.fixed(Symbols.bolt_sharp)),
    ),
  ],
);

final $CustomColors = _Story(
  name: 'Custom Colors',
  args: _Args(
    icon: Arg.fixed(Symbols.bolt_sharp),
    backgroundColor: Arg.fixed(const Color(0xFF2D2D2D)),
    iconColor: Arg.fixed(const Color(0xFFFFD600)),
  ),
);
