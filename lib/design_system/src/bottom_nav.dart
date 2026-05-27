import 'dart:async';

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
    this.onItemLongPress,
    this.longPressDuration = const Duration(seconds: 3),
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

  /// Called when an enabled item is long-pressed.
  ///
  /// Implemented via a transparent overlay row whose long-press
  /// recognizers compete in the gesture arena with the underlying
  /// [NavigationBar] inkwells. Quick taps still resolve to
  /// [onItemSelected]; only long presses held for [longPressDuration]
  /// fire this callback. Disabled items do not emit either.
  final ValueChanged<int>? onItemLongPress;

  /// How long an item must be held before [onItemLongPress] fires.
  /// Defaults to 3 seconds to make the gesture an "intentional power
  /// user" action rather than something a typical tap could trigger.
  final Duration longPressDuration;

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

    // Overlay a transparent row of pointer Listeners so held presses
    // on any item can be observed without re-implementing
    // NavigationBar.
    //
    // We deliberately avoid the gesture arena here. Material's
    // [NavigationBar] wraps each destination in an [InkResponse] whose
    // tap recognizer aggressively claims the arena, which can starve
    // a [LongPressGestureRecognizer] running in a sibling overlay
    // before its timeout fires. Raw [Listener] callbacks bypass the
    // arena entirely: pointer events are delivered to every render
    // object in the hit-test result, so both the InkResponse tap and
    // our hold timer get to observe the same pointer stream
    // independently. Quick taps continue to fire
    // onDestinationSelected; long presses also fire onItemLongPress.
    //
    // The duration is configurable (Flutter's
    // LongPressGestureRecognizer default is kLongPressTimeout = 500 ms,
    // which is much shorter than the "intentional power-user" gesture
    // we want here).
    if (onItemLongPress != null) {
      navBar = Stack(
        children: [
          navBar,
          Positioned.fill(
            child: Row(
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: _LongPressCell(
                      enabled: items[i].enabled,
                      duration: longPressDuration,
                      onLongPress: () => onItemLongPress!.call(i),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

/// Transparent overlay cell that fires [onLongPress] after the user
/// holds for [duration]. Implemented with a raw pointer [Listener]
/// (not [GestureDetector]) so we never enter the gesture arena —
/// quick taps fall through to the [NavigationBar]'s ink response
/// underneath untouched, and the hold detection cannot be starved by
/// a competing recognizer claiming the arena.
class _LongPressCell extends StatefulWidget {
  const _LongPressCell({
    required this.enabled,
    required this.duration,
    required this.onLongPress,
  });

  final bool enabled;
  final Duration duration;
  final VoidCallback onLongPress;

  @override
  State<_LongPressCell> createState() => _LongPressCellState();
}

class _LongPressCellState extends State<_LongPressCell> {
  // Movement past this distance cancels the long-press, matching the
  // touch-slop heuristic used elsewhere in Flutter
  // (`kPanSlop` / `kTouchSlop` are both ~18 logical px).
  static const double _moveSlop = 18.0;

  Timer? _timer;
  Offset? _startPosition;

  void _start(PointerDownEvent event) {
    if (!widget.enabled) return;
    _cancel();
    _startPosition = event.position;
    _timer = Timer(widget.duration, _fire);
  }

  void _onMove(PointerMoveEvent event) {
    final start = _startPosition;
    if (start == null) return;
    if ((event.position - start).distance > _moveSlop) {
      _cancel();
    }
  }

  void _onUp(PointerEvent _) {
    _cancel();
  }

  void _fire() {
    _timer = null;
    _startPosition = null;
    widget.onLongPress();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
    _startPosition = null;
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.expand();
    }
    return Listener(
      // translucent so the InkResponse beneath us in the Stack still
      // receives the same pointer stream for ripples/tap selection.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _start,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: const SizedBox.expand(),
    );
  }
}
