import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/status_badge.dart';

part 'status_badge.stories.g.dart';

const meta = Meta<StatusBadge>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(
    label: StringArg('Active'),
    variant: EnumArg(
      StatusBadgeVariant.success,
      values: StatusBadgeVariant.values,
    ),
    icon: Arg.fixed(Symbols.check_circle_sharp),
  ),
);

final $Error = _Story(
  name: 'Error',
  args: _Args(
    label: StringArg('Failed'),
    variant: EnumArg(
      StatusBadgeVariant.error,
      values: StatusBadgeVariant.values,
    ),
    icon: Arg.fixed(Symbols.error_sharp),
  ),
);

final $Warning = _Story(
  name: 'Warning',
  args: _Args(
    label: StringArg('Pending'),
    variant: EnumArg(
      StatusBadgeVariant.warning,
      values: StatusBadgeVariant.values,
    ),
  ),
);

final $Neutral = _Story(
  name: 'Neutral',
  args: _Args(
    label: StringArg('Offline'),
    variant: EnumArg(
      StatusBadgeVariant.neutral,
      values: StatusBadgeVariant.values,
    ),
  ),
);
