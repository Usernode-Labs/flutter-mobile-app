import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/status_badge.dart';
import 'package:crypto_mobile_app/design_system/src/status_text_trailing.dart';

part 'status_text_trailing.stories.g.dart';

const meta = Meta<StatusTextTrailing>(path: 'widgets/data-display');

final $Default = _Story(
  args: _Args(
    text: StringArg('Connected'),
    variant: EnumArg(
      StatusBadgeVariant.success,
      values: StatusBadgeVariant.values,
    ),
  ),
);

final $Error = _Story(
  name: 'Error',
  args: _Args(
    text: StringArg('Failed'),
    variant: EnumArg(
      StatusBadgeVariant.error,
      values: StatusBadgeVariant.values,
    ),
  ),
);

final $Warning = _Story(
  name: 'Warning',
  args: _Args(
    text: StringArg('Pending'),
    variant: EnumArg(
      StatusBadgeVariant.warning,
      values: StatusBadgeVariant.values,
    ),
  ),
);

final $Info = _Story(
  name: 'Info',
  args: _Args(
    text: StringArg('Syncing'),
    variant: EnumArg(
      StatusBadgeVariant.info,
      values: StatusBadgeVariant.values,
    ),
  ),
);

final $Neutral = _Story(
  name: 'Neutral',
  args: _Args(
    text: StringArg('Inactive'),
    variant: EnumArg(
      StatusBadgeVariant.neutral,
      values: StatusBadgeVariant.values,
    ),
  ),
);
