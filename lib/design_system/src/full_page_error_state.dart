import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'button.dart';

/// A centered error display for use as a full-page body.
///
/// Shows a prominent error icon inside a colored circle, a primary message,
/// an optional detail line, and an optional retry button.
///
/// Presentation-only — takes all state via constructor params.
class FullPageErrorState extends StatelessWidget {
  const FullPageErrorState({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  /// Primary error message, e.g. "Failed to load data".
  final String message;

  /// Optional secondary detail, e.g. the error description.
  final String? detail;

  /// Called when the retry button is pressed. If null, no button is shown.
  final VoidCallback? onRetry;

  /// Label for the retry button. Defaults to "Retry".
  final String retryLabel;

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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.error_sharp,
                size: sizing.iconDisplay,
                color: colors.onErrorContainer,
              ),
            ),
            SizedBox(height: spacing.space16),
            Text(
              message,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              SizedBox(height: spacing.space8),
              Text(
                detail!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: spacing.space24),
              Button(
                label: retryLabel,
                variant: ButtonVariant.primary,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
