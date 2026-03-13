import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'status_badge.dart';

/// A trailing widget that shows a text label followed by a status icon.
///
/// Shape communicates the state (check, X, warning triangle, clock, empty
/// circle) so status is accessible without relying on color alone.
///
/// Commonly used as `ListTile.trailing` for pipeline step rows.
///
/// Presentation-only — takes all state via constructor params.
class StatusTextTrailing extends StatelessWidget {
  const StatusTextTrailing({
    super.key,
    required this.text,
    required this.variant,
  });

  /// The status label displayed before the icon.
  final String text;

  /// Determines the icon shape and foreground color.
  final StatusBadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final textTheme = Theme.of(context).textTheme;

    final Color foreground = switch (variant) {
      StatusBadgeVariant.success => semantic.success.color,
      StatusBadgeVariant.error => colors.error,
      StatusBadgeVariant.warning => semantic.flash.color,
      StatusBadgeVariant.info => semantic.technical.color,
      StatusBadgeVariant.neutral => colors.outline,
    };

    final IconData icon = switch (variant) {
      StatusBadgeVariant.success => Symbols.check_circle_sharp,
      StatusBadgeVariant.error => Symbols.cancel_sharp,
      StatusBadgeVariant.warning => Symbols.warning_sharp,
      StatusBadgeVariant.info => Symbols.schedule_sharp,
      StatusBadgeVariant.neutral => Symbols.radio_button_unchecked_sharp,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.space4,
      children: [
        Text(
          text,
          style: textTheme.bodyMedium?.copyWith(color: foreground),
        ),
        Icon(icon, size: sizing.iconSmall, color: foreground),
      ],
    );
  }
}
