import 'package:flutter/material.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';

/// Visual variant for [StatusBadge].
enum StatusBadgeVariant {
  /// Green — maps to `AppSemanticColors.success`.
  success,

  /// Red — maps to `colorScheme.error`.
  error,

  /// Amber — maps to `AppSemanticColors.flash`.
  warning,

  /// Blue — maps to `AppSemanticColors.technical`.
  info,

  /// Grey — maps to `colorScheme.outline`.
  neutral,
}

/// A compact colored pill showing a status label with optional icon.
///
/// Maps each [StatusBadgeVariant] to semantic colors from the theme,
/// eliminating hardcoded `Colors.*` for status indicators.
///
/// Presentation-only — takes all state via constructor params.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  /// The status text, e.g. "Active", "Failed".
  final String label;

  /// Determines colors from the theme.
  final StatusBadgeVariant variant;

  /// Optional leading icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final textTheme = Theme.of(context).textTheme;

    final (Color foreground, Color background) = switch (variant) {
      StatusBadgeVariant.success => (
          semantic.success.color,
          semantic.success.colorContainer,
        ),
      StatusBadgeVariant.error => (
          colors.error,
          colors.errorContainer,
        ),
      StatusBadgeVariant.warning => (
          semantic.flash.color,
          semantic.flash.colorContainer,
        ),
      StatusBadgeVariant.info => (
          semantic.technical.color,
          semantic.technical.colorContainer,
        ),
      StatusBadgeVariant.neutral => (
          colors.outline,
          colors.surfaceContainerHighest,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space8,
        vertical: spacing.space4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radii.borderRadiusSmall,
        border: Border.all(
          color: foreground.withValues(alpha: opacity.medium),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            SizedBox(width: spacing.space4),
          ],
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
