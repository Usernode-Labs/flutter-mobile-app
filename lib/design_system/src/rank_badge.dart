import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_sizing.dart';

/// A 40px circle showing a rank number, used as a [ListTile.leading] slot
/// in leaderboard ranking rows.
///
/// Uses `surfaceContainerLowest` background with an `outlineVariant` border
/// and centered rank text in `labelLarge` medium weight.
///
/// Presentation-only — takes all state via constructor params.
class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rank,
  });

  /// The rank text to display, e.g. "#1" or "34".
  final String rank;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return Container(
      width: sizing.iconContainerSmall,
      height: sizing.iconContainerSmall,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerLowest,
        border: Border.all(
          color: colors.onSurface.withValues(alpha: borders.opacity),
          width: borders.width,
        ),
      ),
      child: Center(
        child: Text(
          rank,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
