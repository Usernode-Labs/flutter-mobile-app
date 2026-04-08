import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_chain.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_chip.dart';

part 'dropdown_chain.stories.g.dart';

const meta = Meta<DropdownChain>(path: 'widgets/chips');

final $Default = _Story(
  args: _Args(
    items: Arg.fixed([
      DropdownChainItem(label: 'Season 2', onTap: () {}),
      DropdownChainItem(label: 'DApps Integration', onTap: () {}),
    ]),
    variant: EnumArg(ChipVariant.surface, values: ChipVariant.values),
    size: EnumArg(ChipSize.regular, values: ChipSize.values),
  ),
);

final $ThreeItems = _Story(
  name: 'Three Items',
  args: _Args(
    items: Arg.fixed([
      DropdownChainItem(label: 'Season 2', onTap: () {}),
      DropdownChainItem(label: 'DApps', onTap: () {}),
      DropdownChainItem(label: 'Active', onTap: () {}),
    ]),
    variant: EnumArg(ChipVariant.outlined, values: ChipVariant.values),
    size: EnumArg(ChipSize.regular, values: ChipSize.values),
  ),
);
