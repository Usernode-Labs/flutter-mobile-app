import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// A lean filter chip with a dropdown chevron, built from Flutter primitives.
///
/// Used for filter rows where the user taps to select from options via a
/// bottom sheet or menu. Presentation-only — the screen manages selection
/// state and passes the current label.
///
/// Built bottom-up: [GestureDetector] + [Container] + [Row] + [Text] + [Icon].
/// No Material Chip classes.
class DropdownChip extends StatelessWidget {
  const DropdownChip({
    super.key,
    required this.label,
    this.onTap,
    this.expanded = false,
    this.selected = false,
    this.enabled = true,
  });

  /// The chip label text, e.g. "Season 2" or "DApps Integration".
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// When true, the chip fills available width (wraps in [Expanded]).
  /// When false, the chip shrink-wraps to its content.
  final bool expanded;

  /// When true, the chip uses `secondaryContainer` fill and
  /// `onSecondaryContainer` text/icon color to indicate active selection.
  final bool selected;

  /// When false, the chip is visually dimmed via [AppOpacity.disabled] and
  /// ignores taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    final contentColor =
        selected ? colors.onSecondaryContainer : colors.onSurfaceVariant;

    Widget chip = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 32,
        padding: EdgeInsets.only(
          left: spacing.space16,
          right: spacing.space8,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.secondaryContainer : null,
          border: Border.all(color: colors.outlineVariant),
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
      chip = Opacity(opacity: opacity.disabled, child: chip);
    }

    return chip;
  }
}
