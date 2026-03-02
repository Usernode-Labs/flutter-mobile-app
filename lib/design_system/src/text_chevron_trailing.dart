import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

/// A trailing widget that shows text followed by a chevron-right icon.
///
/// Commonly used as `ListTile.trailing` to indicate a tappable row that
/// navigates somewhere while still displaying a value.
///
/// Presentation-only — takes all state via constructor params.
class TextChevronTrailing extends StatelessWidget {
  const TextChevronTrailing({super.key, required this.text});

  /// The text displayed before the chevron icon.
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        SizedBox(width: spacing.space4),
        Icon(Icons.chevron_right, size: 20, color: cs.onSurfaceVariant),
      ],
    );
  }
}
