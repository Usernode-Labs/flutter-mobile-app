import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// Lightweight layout scaffold for bottom sheet content.
///
/// Provides [SafeArea], optional [title] header, and wraps the [child] in
/// [Flexible] so it works inside the [Column] that bottom sheets use.
///
/// Presentation-only — takes all state via constructor params.
class SheetLayout extends StatelessWidget {
  const SheetLayout({
    super.key,
    this.title,
    required this.child,
  });

  /// Optional title displayed above the content.
  /// Rendered as `titleMedium` with `w600` weight.
  final String? title;

  /// The main content of the sheet.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: spacing.space16,
                  right: spacing.space16,
                  top: spacing.space16,
                ),
                child: Text(
                  title!,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              SizedBox(height: spacing.space8),
            ],
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
