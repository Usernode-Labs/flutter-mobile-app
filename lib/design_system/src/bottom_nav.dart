import 'package:flutter/material.dart';

import 'nav_indicator_shapes.dart';

/// Data class for a single bottom navigation item.
///
/// Uses a single [icon] field. Fill is controlled at the widget level:
/// selected items render with `fill: 1` (filled), unselected with `fill: 0`
/// (outline). Use Material Symbols Sharp icons (e.g. `Symbols.settings_sharp`).
class BottomNavItem {
  /// Creates a bottom nav item.
  const BottomNavItem({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.enabled = true,
    this.indicatorShape,
    this.indicatorColor,
    this.indicatorFillColor,
  });

  /// Icon glyph. Fill is controlled by BottomNav based on selection state.
  final IconData icon;

  /// Label text below the icon.
  final String label;

  /// Badge count. Null or 0 means no badge is shown.
  final int? badgeCount;

  /// Whether the item is tappable. False = 50% opacity, non-tappable.
  final bool enabled;

  /// Geometric shape for the selection indicator. Null means no indicator.
  final NavIndicatorShape? indicatorShape;

  /// Accent color for the selected icon.
  /// Null falls back to `colorScheme.primary`.
  final Color? indicatorColor;

  /// Fill color for the indicator shape background.
  /// Pass semantic `colorContainer` for the light tint.
  /// Falls back to [indicatorColor] at 20% opacity if null.
  final Color? indicatorFillColor;
}

/// A bottom navigation bar wrapping M3 [NavigationBar].
///
/// 80dp height, 24px icons, labelMedium labels. Active state uses filled
/// icon (`fill: 1`) with [indicatorColor], inactive uses outlined icon
/// (`fill: 0`) with `outline` color.
///
/// Gains ripple, focus, keyboard navigation, and screen reader semantics
/// from the underlying M3 component. Visual appearance is controlled by
/// `navigationBarTheme` in [ColorIsExpensiveTheme].
///
/// Presentation-only — parent manages selection state via [selectedIndex]
/// and [onItemSelected] callback.
class BottomNav extends StatelessWidget {
  /// Creates a bottom navigation bar.
  ///
  /// [items] must have between 2 and 5 entries.
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onItemSelected,
    this.topBorder = true,
  }) : assert(
          items.length >= 2 && items.length <= 5,
          'items must have between 2 and 5 entries',
        );

  /// Navigation items (2-5).
  final List<BottomNavItem> items;

  /// Currently selected item index.
  final int selectedIndex;

  /// Called when an enabled item is tapped.
  final ValueChanged<int>? onItemSelected;

  /// Whether to show an `outlineVariant` top border. Defaults to true.
  /// Set to false when the parent provides its own border (e.g. network indicator).
  final bool topBorder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = items[selectedIndex];

    // Per-selection shape: rebuild with the selected item's indicator.
    final ShapeBorder? indicatorShape = selected.indicatorShape != null
        ? shapeBorderFor(selected.indicatorShape!)
        : null;
    final Color indicatorColor = selected.indicatorFillColor ??
        selected.indicatorColor?.withValues(alpha: 0.2) ??
        Colors.transparent;

    final navBar = NavigationBar(
      selectedIndex: selectedIndex,
      indicatorShape: indicatorShape,
      indicatorColor: indicatorColor,
      onDestinationSelected: (index) {
        if (items[index].enabled) {
          onItemSelected?.call(index);
        }
      },
      destinations: [
        for (int i = 0; i < items.length; i++)
          _buildDestination(context, items[i], selected: i == selectedIndex),
      ],
    );

    if (!topBorder) return navBar;

    return DecoratedBox(
      // Foreground so the border paints on top of NavigationBar's opaque
      // background (surfaceContainerLowest from ColorIsExpensiveTheme).
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: navBar,
    );
  }

  NavigationDestination _buildDestination(
    BuildContext context,
    BottomNavItem item, {
    required bool selected,
  }) {
    final hasBadge = item.badgeCount != null && item.badgeCount! > 0;
    final colors = Theme.of(context).colorScheme;
    final disabledOpacity = item.enabled ? 1.0 : 0.5;

    Widget buildIcon({required bool filled}) {
      final color =
          filled ? (item.indicatorColor ?? colors.primary) : colors.outline;
      Widget iconWidget = Opacity(
        opacity: disabledOpacity,
        child: Icon(item.icon, fill: filled ? 1 : 0, size: 24, color: color),
      );
      if (hasBadge) {
        iconWidget = Badge(
          label: Text(
            '${item.badgeCount}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onError,
                  height: 1,
                ),
          ),
          backgroundColor: colors.error,
          child: iconWidget,
        );
      }
      return iconWidget;
    }

    return NavigationDestination(
      icon: buildIcon(filled: false),
      selectedIcon: buildIcon(filled: true),
      label: item.label,
      enabled: item.enabled,
    );
  }
}
