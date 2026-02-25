import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// A lean filter chip with a dropdown chevron, wrapping M3 [FilterChip].
///
/// Used for filter rows where the user taps to select from options via a
/// bottom sheet or menu. Presentation-only — the screen manages selection
/// state and passes the current label.
///
/// Built bottom-up: [GestureDetector] + [Container] + [Row] + [Text] + [Icon].
class DropdownChip extends StatelessWidget {
  const DropdownChip({
    super.key,
    required this.label,
    this.onTap,
    this.expanded = false,
    this.selected = false,
    this.enabled = true,
    this.borderColor,
  });

  /// The chip label text, e.g. "Season 2" or "DApps Integration".
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// When true, the chip fills available width.
  /// When false, the chip shrink-wraps to its content.
  final bool expanded;

  /// When true, the chip uses `surfaceContainerLowest` (white) fill with no
  /// border. When false, the chip is outlined with no fill.
  final bool selected;

  /// When false, the chip is visually dimmed via [AppOpacity.disabled] and
  /// ignores taps.
  final bool enabled;

  /// Optional explicit border color. When null, defaults to transparent when
  /// [selected] or `outlineVariant` when unselected.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final contentColor = selected ? colors.onSurface : colors.onSurfaceVariant;

    Widget chip = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 32,
        padding: EdgeInsets.only(
          left: spacing.space16,
          right: spacing.space8,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceContainerLowest : null,
          border: Border.all(
            color: borderColor ??
                (selected ? Colors.transparent : colors.outlineVariant),
          ),
          borderRadius: radii.borderRadiusSmall,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            expanded
                ? Expanded(
                    child: Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        color: contentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      color: contentColor,
                    ),
                  ),
            SizedBox(width: spacing.space8),
            Icon(
              Icons.arrow_drop_down,
              size: 24,
              color: contentColor,
            ),
          ],
        ),
      ),
    );

    if (!enabled) {
      final opacity = Theme.of(context).extension<AppOpacity>()!;
      chip = IgnorePointer(
        child: Opacity(opacity: opacity.disabled, child: chip),
      );
    }

    return chip;
  }
}
