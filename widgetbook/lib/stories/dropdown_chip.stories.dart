import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_chip.dart';

part 'dropdown_chip.stories.g.dart';

const meta = MetaWithArgs<DropdownChip, DropdownChipStoryModel>(
  path: 'live app/widgets/chips',
);

final defaults = _Defaults(builder: _buildDropdownChip);

class DropdownChipStoryModel {
  const DropdownChipStoryModel({
    this.label = 'Season 2',
    this.onTap,
    this.expanded = false,
    this.variant = ChipVariant.outlined,
    this.size = ChipSize.regular,
    this.enabled = true,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool expanded;
  final ChipVariant variant;
  final ChipSize size;
  final bool enabled;
  final Color? borderColor;
}

DropdownChip _buildDropdownChip(
  BuildContext context,
  DropdownChipStoryModelArgs args,
) {
  return DropdownChip(
    label: args.label,
    onTap: args.onTap,
    expanded: args.expanded,
    variant: args.variant,
    size: args.size,
    enabled: args.enabled,
    borderColor: args.borderColor,
  );
}

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
