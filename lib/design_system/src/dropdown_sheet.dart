import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// Shows a custom bottom sheet with selectable options.
///
/// Returns the index of the selected option, or `null` if dismissed
/// (tap barrier or drag down).
///
/// Built from [PopupRoute] (core widgets library) — no Material
/// `showModalBottomSheet`. Drag-to-dismiss, barrier tap, and slide-up
/// animation are all hand-rolled from primitives.
Future<int?> showDropdownSheet({
  required BuildContext context,
  required List<String> labels,
  String? title,
  int? selectedIndex,
}) {
  // Capture the caller's ThemeData so the route overlay (which may sit above
  // the Theme widget in the tree, e.g. in Widgetbook) still sees all
  // design-system extensions.
  final theme = Theme.of(context);
  return Navigator.of(context).push<int>(
    _DropdownSheetRoute(
      labels: labels,
      title: title,
      selectedIndex: selectedIndex,
      animationTokens: theme.extension<AppAnimation>()!,
      themeData: theme,
    ),
  );
}

class _DropdownSheetRoute extends PopupRoute<int> {
  _DropdownSheetRoute({
    required this.labels,
    required this.animationTokens,
    required this.themeData,
    this.title,
    this.selectedIndex,
  });

  final List<String> labels;
  final String? title;
  final int? selectedIndex;
  final AppAnimation animationTokens;
  final ThemeData themeData;

  @override
  Color? get barrierColor => const Color(0x80000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => animationTokens.complex;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> anim,
    Animation<double> secondaryAnim,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> anim,
    Animation<double> secondaryAnim,
  ) {
    // Re-inject the caller's theme so design-system extensions are available
    // inside the overlay (which may sit above the Theme widget in the tree).
    return Theme(
      data: themeData,
      child: _DropdownSheetBody(
        labels: labels,
        title: title,
        selectedIndex: selectedIndex,
      ),
    );
  }
}

class _DropdownSheetBody extends StatefulWidget {
  const _DropdownSheetBody({
    required this.labels,
    this.title,
    this.selectedIndex,
  });

  final List<String> labels;
  final String? title;
  final int? selectedIndex;

  @override
  State<_DropdownSheetBody> createState() => _DropdownSheetBodyState();
}

class _DropdownSheetBodyState extends State<_DropdownSheetBody> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    // Only allow dragging downward.
    final newOffset = _dragOffset + details.delta.dy;
    if (newOffset < 0) return;
    setState(() => _dragOffset = newOffset);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > 100 || velocity > 700) {
      Navigator.of(context).pop();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.6),
          child: GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: radii.borderRadiusTopXLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.space12),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.onSurfaceVariant
                              .withValues(alpha: opacity.secondary),
                          borderRadius: radii.borderRadiusFull,
                        ),
                      ),
                    ),
                  ),

                  // Title row
                  if (widget.title != null)
                    Padding(
                      padding: EdgeInsets.only(
                        left: spacing.space16,
                        right: spacing.space8,
                        bottom: spacing.space8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title!,
                              style: textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Padding(
                              padding: EdgeInsets.all(spacing.space8),
                              child: Icon(
                                Icons.close,
                                size: 24,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Option list
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      itemCount: widget.labels.length,
                      itemBuilder: (context, index) {
                        final isSelected = index == widget.selectedIndex;
                        return _OptionRow(
                          label: widget.labels[index],
                          selected: isSelected,
                          onTap: () => Navigator.of(context).pop(index),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check, size: 24, color: colors.primary)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}
