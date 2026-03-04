import 'package:flutter/material.dart';
import '../tokens/app_spacing.dart';

/// Section header for grouped lists — renders [title] in `labelLarge` /
/// `onSurfaceVariant` with bottom spacing.
class ListSectionHeader extends StatelessWidget {
  const ListSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.space8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
