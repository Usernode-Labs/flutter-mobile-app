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
  scenarios: [
    _Scenario(
      name: 'With divider',
      args: _Args.fixed(
        label: 'Block Hash',
        value: '0x7a3f…e91b',
        showDivider: true,
      ),
    ),
    _Scenario(
      name: 'Without divider',
      args: _Args.fixed(
        label: 'Status',
        value: 'Active',
        showDivider: false,
      ),
    ),
    _Scenario(
      name: 'Tappable with trailing',
      args: _Args.fixed(
        label: 'Epoch',
        value: '42',
        showDivider: true,
        trailing: Icon(Symbols.chevron_right_sharp, size: 20),
        onTap: () {},
      ),
    ),
    _Scenario(
      name: 'Non-tappable no divider',
      args: _Args.fixed(
        label: 'Version',
        value: '1.0.0',
        showDivider: false,
      ),
    ),
  ],
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
