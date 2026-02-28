import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';

/// Chip height — mirrors [ButtonSize] for consistency.
enum ChipSize {
  /// 28px height — compact filters.
  small,

  /// 32px height (default) — standard filters.
  regular,
}

/// Chip visual variant — mirrors [ButtonVariant] for consistency.
enum ChipVariant {
  /// Soft tonal fill (`secondaryContainer`), no border (default).
  tonal,

  /// Transparent fill with `outlineVariant` border.
  outlined,

  /// White fill (`surfaceContainerLowest`), no border — for dark backgrounds.
  surface,
}

/// A lean filter chip with a dropdown chevron.
///
/// Used for filter rows where the user taps to select from options via a
/// bottom sheet or menu. Supports three visual variants ([ChipVariant]) and
/// two sizes ([ChipSize]), mirroring the [Button] widget's organization.
///
/// Presentation-only — the screen manages selection state and passes the
/// current label.
class DropdownChip extends StatelessWidget {
  const DropdownChip({
    super.key,
    required this.label,
    this.onTap,
    this.expanded = false,
    this.variant = ChipVariant.outlined,
    this.size = ChipSize.regular,
    this.enabled = true,
    this.borderColor,
    @Deprecated('Use variant instead. '
        'selected=true maps to ChipVariant.surface, '
        'selected=false maps to ChipVariant.outlined.')
    this.selected,
  });

  /// The chip label text, e.g. "Season 2" or "DApps Integration".
  final String label;

  /// Called when the chip is tapped.
  final VoidCallback? onTap;

  /// When true, the chip fills available width.
  /// When false, the chip shrink-wraps to its content.
  final bool expanded;

  /// Visual variant. Defaults to [ChipVariant.outlined].
  final ChipVariant variant;

  /// Chip height. Defaults to [ChipSize.regular] (32px).
  final ChipSize size;

  /// When false, the chip is visually dimmed via [AppOpacity.disabled] and
  /// ignores taps.
  final bool enabled;

  /// Optional explicit border color override.
  final Color? borderColor;

  /// Legacy parameter — use [variant] instead.
  final bool? selected;

  /// Resolves the effective variant, accounting for the deprecated [selected].
  ChipVariant get _effectiveVariant {
    if (selected != null) {
      return selected! ? ChipVariant.surface : ChipVariant.outlined;
    }
    return variant;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final effectiveVariant = _effectiveVariant;

    final height = switch (size) {
      ChipSize.small => 28.0,
      ChipSize.regular => 32.0,
    };

    final iconSize = switch (size) {
      ChipSize.small => 20.0,
      ChipSize.regular => 24.0,
    };

    final textStyle = switch (size) {
      ChipSize.small => textTheme.labelMedium,
      ChipSize.regular => textTheme.labelLarge,
    };

    final (Color? fill, Color defaultBorder, Color contentColor) =
        switch (effectiveVariant) {
      ChipVariant.tonal => (
          colors.secondaryContainer,
          Colors.transparent,
          colors.onSecondaryContainer,
        ),
      ChipVariant.outlined => (
          null,
          colors.outlineVariant,
          colors.onSurfaceVariant,
        ),
      ChipVariant.surface => (
          colors.surfaceContainerLowest,
          Colors.transparent,
          colors.onSurface,
        ),
    };

    Widget chip = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: height,
        padding: EdgeInsets.only(
          left: spacing.space16,
          right: spacing.space8,
        ),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: borderColor ?? defaultBorder),
          borderRadius: radii.borderRadiusSmall,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            expanded
                ? Expanded(
                    child: Text(
                      label,
                      style: textStyle?.copyWith(color: contentColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    label,
                    style: textStyle?.copyWith(color: contentColor),
                  ),
            SizedBox(width: spacing.space8),
            Icon(
              Icons.arrow_drop_down,
              size: iconSize,
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
