import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'empty_state.dart';

/// A centered error display for use as a full-page body.
///
/// Shows an error icon, a primary message, an optional detail line,
/// and an optional retry button. Delegates to [EmptyState] internally.
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
    return EmptyState(
      icon: Symbols.error_sharp,
      title: message,
      subtitle: detail,
      action: onRetry != null
          ? FilledButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            )
          : null,
    );
  }
}
