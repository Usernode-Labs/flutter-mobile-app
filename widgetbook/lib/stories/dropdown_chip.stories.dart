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
