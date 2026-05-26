import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
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
  /// Pass semantic `colorSurface` for the faint tint.
  /// Falls back to transparent if null.
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

  // Compact NavigationBar content height (M3 default is 80dp). 56dp is
  // just enough to hold the 24dp icon + 4dp gap + 16dp label column with
  // a small padding ring, while the 32dp indicator pill still fits because
  // we add some absorbed safe-area space to the bar's effective height
  // below.
  static const double _navBarHeight = 56.0;

  // Fraction of the OS bottom safe-area inset to bake into the bar's own
  // content height so centered items shift down into the absorbed region.
  // The remaining (1 - this) of the inset stays as SafeArea padding below
  // the bar so the home-indicator gesture area is untouched. At 0.25 on a
  // 34dp iPhone inset this lands icons ~57dp above the screen edge with
  // ~20dp of empty space between the body content and the top of the
  // icons.
  static const double _safeAreaAbsorbFraction = 0.25;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final selected = items[selectedIndex];

    // Per-selection shape: rebuild with the selected item's indicator.
    final ShapeBorder? indicatorShape = selected.indicatorShape != null
        ? shapeBorderFor(selected.indicatorShape!)
        : null;
    final Color indicatorColor =
        selected.indicatorFillColor ?? Colors.transparent;

    // Bake half the bottom OS inset into the bar's content height so
    // centered items slide down by that amount; the other half stays as
    // SafeArea padding below the bar. This pulls icons close to the
    // rounded screen edge without overlapping the home-indicator region
    // and without leaving a wide empty colored strip below the icons.
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;
    final absorbedInset = bottomInset * _safeAreaAbsorbFraction;
    final remainingInset = bottomInset - absorbedInset;

    Widget navBar = NavigationBar(
      selectedIndex: selectedIndex,
      indicatorShape: indicatorShape,
      indicatorColor: indicatorColor,
      height: _navBarHeight + absorbedInset,
      // M3's default labelMedium (12sp) makes longer strings like
      // "Node Status" wrap to two lines on narrower phones (iPhone 13
      // mini, SE) because NavigationDestination renders the label as a
      // bare softWrap-true Text. Drop a notch to labelSmall (11sp), which
      // fits comfortably while staying inside the M3 typography scale.
      labelTextStyle: _compactLabelTextStyle(context),
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

    // Tell NavigationBar's internal SafeArea that only [remainingInset]
    // of the OS inset is unaccounted for; the rest is now part of the
    // height we passed. Without this override SafeArea would add the
    // full inset on top of the absorbed amount, double-counting it.
    if (bottomInset > 0) {
      navBar = MediaQuery(
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(bottom: remainingInset),
        ),
        child: navBar,
      );
    }

    if (!topBorder) return navBar;

    return DecoratedBox(
      // Foreground so the border paints on top of NavigationBar's opaque
      // background (surfaceContainerLowest from ColorIsExpensiveTheme).
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colors.onSurface.withValues(alpha: borders.opacity),
            width: borders.width,
          ),
        ),
      ),
      child: navBar,
    );
  }

  // Mirrors M3's default NavigationBar label color logic (selected uses
  // onSurface, unselected uses onSurfaceVariant, disabled fades to 38%),
  // but swaps the base style from labelMedium to labelSmall so the text
  // is one M3 step smaller. Passing widget-level [labelTextStyle] fully
  // bypasses the theme/defaults chain, so we have to provide colors too.
  WidgetStateProperty<TextStyle?> _compactLabelTextStyle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.labelSmall;
    return WidgetStateProperty.resolveWith<TextStyle?>((states) {
      final Color color;
      if (states.contains(WidgetState.disabled)) {
        color = colors.onSurfaceVariant.withValues(alpha: 0.38);
      } else if (states.contains(WidgetState.selected)) {
        color = colors.onSurface;
      } else {
        color = colors.onSurfaceVariant;
      }
      return base?.copyWith(color: color);
    });
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
        child: Icon(item.icon, fill: filled ? 1 : 0, color: color),
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
