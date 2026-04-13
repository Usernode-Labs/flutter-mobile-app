import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_chip.dart';

part 'dropdown_chip.stories.g.dart';

const meta = Meta<DropdownChip>(path: 'widgets/chips');

final $Default = _Story(
  args: _Args(
    label: StringArg('Season 2'),
    onTap: Arg.fixed(() {}),
    expanded: BoolArg(false),
    variant: EnumArg(ChipVariant.outlined, values: ChipVariant.values),
    size: EnumArg(ChipSize.regular, values: ChipSize.values),
    enabled: BoolArg(true),
  ),
  scenarios: [
    _Scenario(
      name: 'Outlined variant',
      args: _Args.fixed(
        label: 'Season 2',
        onTap: () {},
        variant: ChipVariant.outlined,
      ),
    ),
    _Scenario(
      name: 'Surface variant',
      args: _Args.fixed(
        label: 'Season 2',
        onTap: () {},
        variant: ChipVariant.surface,
      ),
    ),
    _Scenario(
      name: 'Expanded',
      args: _Args.fixed(
        label: 'Season 2',
        onTap: () {},
        expanded: true,
        variant: ChipVariant.outlined,
      ),
    ),
    _Scenario(
      name: 'Disabled',
      args: _Args.fixed(
        label: 'Unavailable',
        onTap: () {},
        enabled: false,
        variant: ChipVariant.outlined,
      ),
    ),
    _Scenario(
      name: 'Compact size',
      args: _Args.fixed(
        label: 'Season 2',
        onTap: () {},
        size: ChipSize.small,
        variant: ChipVariant.outlined,
      ),
    ),
  ],
);

final $Surface = _Story(
  name: 'Surface',
  args: _Args(
    label: StringArg('DApps Integration'),
    onTap: Arg.fixed(() {}),
    expanded: BoolArg(false),
    variant: EnumArg(ChipVariant.surface, values: ChipVariant.values),
    size: EnumArg(ChipSize.regular, values: ChipSize.values),
    enabled: BoolArg(true),
  ),
);

final $Disabled = _Story(
  name: 'Disabled',
  args: _Args(
    label: StringArg('Unavailable'),
    onTap: Arg.fixed(() {}),
    expanded: BoolArg(false),
    variant: EnumArg(ChipVariant.outlined, values: ChipVariant.values),
    size: EnumArg(ChipSize.regular, values: ChipSize.values),
    enabled: BoolArg(false),
  ),
);
