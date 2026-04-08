import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/info_row.dart';

part 'info_row.stories.g.dart';

const meta = Meta<InfoRow>(path: 'widgets/data-display');

final $Default = _Story(
  args: _Args(
    label: StringArg('Block Hash'),
    value: StringArg('0x7a3f…e91b'),
    showDivider: BoolArg(true),
    trailing: Arg.fixed(null),
    onTap: Arg.fixed(null),
    valueStyle: Arg.fixed(null),
    contentPadding: Arg.fixed(null),
  ),
);

final $Tappable = _Story(
  name: 'Tappable',
  args: _Args(
    label: StringArg('Epoch'),
    value: StringArg('42'),
    showDivider: BoolArg(true),
    trailing: Arg.fixed(const Icon(Symbols.chevron_right_sharp, size: 20)),
    onTap: Arg.fixed(() {}),
    valueStyle: Arg.fixed(null),
    contentPadding: Arg.fixed(null),
  ),
);

final $NoDivider = _Story(
  name: 'No Divider',
  args: _Args(
    label: StringArg('Status'),
    value: StringArg('Active'),
    showDivider: BoolArg(false),
    trailing: Arg.fixed(null),
    onTap: Arg.fixed(null),
    valueStyle: Arg.fixed(null),
    contentPadding: Arg.fixed(null),
  ),
);
