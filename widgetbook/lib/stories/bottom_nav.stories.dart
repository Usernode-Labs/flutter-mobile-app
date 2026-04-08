import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/bottom_nav.dart';
import 'package:crypto_mobile_app/design_system/src/nav_indicator_shapes.dart';

part 'bottom_nav.stories.g.dart';

const meta = Meta<BottomNav>(path: 'widgets/navigation');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    items: Arg.fixed(const [
      BottomNavItem(
        icon: Symbols.account_balance_wallet_sharp,
        label: 'Wallet',
        indicatorShape: NavIndicatorShape.hexagon,
      ),
      BottomNavItem(
        icon: Symbols.hub_sharp,
        label: 'Node',
        indicatorShape: NavIndicatorShape.circle,
      ),
      BottomNavItem(
        icon: Symbols.emoji_events_sharp,
        label: 'Challenges',
        badgeCount: 3,
        indicatorShape: NavIndicatorShape.blob,
      ),
      BottomNavItem(
        icon: Symbols.language_sharp,
        label: 'dApps',
        indicatorShape: NavIndicatorShape.circle,
      ),
      BottomNavItem(
        icon: Symbols.settings_sharp,
        label: 'Settings',
        indicatorShape: NavIndicatorShape.circle,
      ),
    ]),
    selectedIndex: IntArg(0),
    topBorder: BoolArg(true),
    onItemSelected: Arg.fixed(null),
  ),
);
