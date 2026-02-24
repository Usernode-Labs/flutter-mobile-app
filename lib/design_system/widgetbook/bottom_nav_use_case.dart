import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/bottom_nav.dart';
import '../src/nav_indicator_shapes.dart';
import '../tokens/app_semantic_colors.dart';

WidgetbookComponent bottomNavComponent() {
  return WidgetbookComponent(
    name: 'BottomNav',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final itemCount = context.knobs.int.slider(
            label: 'Item count',
            initialValue: 5,
            min: 3,
            max: 5,
          );

          final showBadge = context.knobs.boolean(
            label: 'Show badge',
            initialValue: true,
          );

          final hasDisabled = context.knobs.boolean(
            label: 'Disabled item',
            initialValue: false,
          );

          final showShapes = context.knobs.boolean(
            label: 'Category shapes',
            initialValue: true,
          );

          return _InteractiveBottomNav(
            itemCount: itemCount,
            showBadge: showBadge,
            hasDisabled: hasDisabled,
            showShapes: showShapes,
          );
        },
      ),
    ],
  );
}

/// Stateful wrapper so tapping items updates the selection in Widgetbook.
class _InteractiveBottomNav extends StatefulWidget {
  const _InteractiveBottomNav({
    required this.itemCount,
    required this.showBadge,
    required this.hasDisabled,
    required this.showShapes,
  });

  final int itemCount;
  final bool showBadge;
  final bool hasDisabled;
  final bool showShapes;

  @override
  State<_InteractiveBottomNav> createState() => _InteractiveBottomNavState();
}

class _InteractiveBottomNavState extends State<_InteractiveBottomNav> {
  int _selectedIndex = 0;

  @override
  void didUpdateWidget(_InteractiveBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex >= widget.itemCount) {
      _selectedIndex = widget.itemCount - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();

    final allItems = [
      BottomNavItem(
        icon: Symbols.cards_star_sharp,
        label: 'Challenges',
        badgeCount: widget.showBadge ? 3 : null,
        indicatorShape: widget.showShapes ? NavIndicatorShape.circle : null,
        indicatorColor: widget.showShapes ? semantic?.flash.color : null,
        indicatorFillColor:
            widget.showShapes ? semantic?.flash.colorContainer : null,
      ),
      BottomNavItem(
        icon: Symbols.action_key_sharp,
        label: 'DApps',
        indicatorShape: widget.showShapes ? NavIndicatorShape.blob : null,
        indicatorColor: widget.showShapes ? semantic?.community.color : null,
        indicatorFillColor:
            widget.showShapes ? semantic?.community.colorContainer : null,
      ),
      BottomNavItem(
        icon: Symbols.account_balance_wallet_sharp,
        label: 'Wallet',
        indicatorShape: widget.showShapes ? NavIndicatorShape.circle : null,
        indicatorColor: widget.showShapes ? semantic?.flash.color : null,
        indicatorFillColor:
            widget.showShapes ? semantic?.flash.colorContainer : null,
      ),
      BottomNavItem(
        icon: Symbols.check_circle_sharp,
        label: 'Nodes',
        enabled: !widget.hasDisabled,
        indicatorShape: widget.showShapes ? NavIndicatorShape.hexagon : null,
        indicatorColor: widget.showShapes ? semantic?.technical.color : null,
        indicatorFillColor:
            widget.showShapes ? semantic?.technical.colorContainer : null,
      ),
      BottomNavItem(
        icon: Symbols.settings_sharp,
        label: 'Settings',
        indicatorShape: widget.showShapes ? NavIndicatorShape.hexagon : null,
        indicatorColor: widget.showShapes ? semantic?.technical.color : null,
        indicatorFillColor:
            widget.showShapes ? semantic?.technical.colorContainer : null,
      ),
    ];

    final items = allItems.take(widget.itemCount).toList();
    final label = items[_selectedIndex].label;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(
              'Page: $label',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        BottomNav(
          items: items,
          selectedIndex: _selectedIndex,
          onItemSelected: (index) => setState(() => _selectedIndex = index),
        ),
      ],
    );
  }
}
