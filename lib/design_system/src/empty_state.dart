import 'package:flutter/material.dart';

import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// A centered empty-state placeholder with icon, title, optional subtitle,
/// and optional action button.
///
/// Used when a list, page, or section has no content to display.
///
/// Presentation-only — takes all state via constructor params.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  /// The large muted icon displayed above the title.
  final IconData icon;

  /// The primary message, e.g. "No transactions yet".
  final String title;

  /// Optional secondary message with more detail.
  final String? subtitle;

  /// Optional action widget (typically a [Button]).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.space16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: sizing.iconDisplay,
              color: colors.onSurfaceVariant,
            ),
            SizedBox(height: spacing.space16),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: spacing.space24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
