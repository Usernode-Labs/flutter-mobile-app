import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_spacing.dart';

/// A key-value row displaying a label on the left and a value on the right.
///
/// Used in detail screens for displaying metadata (block hash, epoch, etc.).
/// Supports optional trailing widget, tap handler, and bottom divider.
///
/// Presentation-only — takes all state via constructor params.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.contentPadding,
  });

  /// The label text on the left side.
  final String label;

  /// The value text on the right side.
  final String value;

  /// Optional override for the value text style (e.g. monospace for hashes).
  final TextStyle? valueStyle;

  /// Optional trailing widget after the value (e.g. copy button, chevron).
  final Widget? trailing;

  /// If provided, the row becomes tappable with ink splash.
  final VoidCallback? onTap;

  /// Whether to show a thin divider at the bottom. Defaults to true.
  final bool showDivider;

  /// Padding around the row content.
  /// Defaults to horizontal space16, vertical space12 (matching M3 ListTile).
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;

    final resolvedPadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: spacing.space16,
          vertical: spacing.space12,
        );

    final content = Padding(
      padding: resolvedPadding,
      child: Row(
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(width: spacing.space16),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                  ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: spacing.space8),
            trailing!,
          ],
        ],
      ),
    );

    final row = onTap != null ? InkWell(onTap: onTap, child: content) : content;

    if (!showDivider) return row;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Divider(
          height: borders.width,
          thickness: borders.width,
          color: colors.onSurface.withValues(alpha: borders.opacity),
        ),
      ],
    );
  }
}
