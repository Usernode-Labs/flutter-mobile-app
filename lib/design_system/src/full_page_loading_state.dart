import 'package:flutter/material.dart';

/// A centered loading indicator for use as a full-page body.
///
/// Designed for the `body:` slot of a [Scaffold] when the entire screen
/// is waiting for data. For inline/partial loading, use a local
/// [CircularProgressIndicator] directly.
///
/// Presentation-only — takes all state via constructor params.
class FullPageLoadingState extends StatelessWidget {
  const FullPageLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}
