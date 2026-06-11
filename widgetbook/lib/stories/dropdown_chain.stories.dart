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
  scenarios: [
    _Scenario(
      name: 'Surface variant',
      args: _Args.fixed(
        items: [
          DropdownChainItem(label: 'Season 2', onTap: () {}),
          DropdownChainItem(label: 'DApps Integration', onTap: () {}),
        ],
        variant: ChipVariant.surface,
      ),
    ),
    _Scenario(
      name: 'Outlined variant',
      args: _Args.fixed(
        items: [
          DropdownChainItem(label: 'Season 2', onTap: () {}),
          DropdownChainItem(label: 'DApps Integration', onTap: () {}),
        ],
        variant: ChipVariant.outlined,
      ),
    ),
    _Scenario(
      name: 'Compact size',
      args: _Args.fixed(
        items: [
          DropdownChainItem(label: 'Season 2', onTap: () {}),
          DropdownChainItem(label: 'DApps', onTap: () {}),
        ],
        size: ChipSize.small,
      ),
    ),
  ],
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
