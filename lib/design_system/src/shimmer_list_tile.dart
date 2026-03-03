import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'shimmer_block.dart';

/// A skeleton placeholder shaped like a [ListTile] with an [IconBadge]-sized
/// leading element.
///
/// Composes [ShimmerBlock] instances to match the visual structure of a
/// three-line list tile, giving users spatial context during data loading.
///
/// Uses [Padding] matching [ListTile] content padding for visual consistency
/// with real tiles.
class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({
    super.key,
    this.isThreeLine = true,
    this.hasTrailing = true,
  });

  /// Whether to show three lines of text (title + two subtitle lines).
  /// Matches the transaction tile structure when `true`.
  final bool isThreeLine;

  /// Whether to show a trailing block (e.g., amount placeholder).
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    // Match ListTile's default content padding.
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space16,
        vertical: spacing.space12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading — circular, matches IconBadge 3-layer surface size (40px).
          ShimmerBlock(
            width: sizing.iconContainerSmall,
            height: sizing.iconContainerSmall,
            borderRadius: radii.borderRadiusFull,
          ),
          SizedBox(width: spacing.space16),

          // Title + subtitle lines.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line — ~60% width.
                const ShimmerBlock(width: 120, height: 14),
                SizedBox(height: spacing.space8),
                // Subtitle line 1 — ~80% width.
                const ShimmerBlock(width: 180, height: 12),
                if (isThreeLine) ...[
                  SizedBox(height: spacing.space4),
                  // Subtitle line 2 — ~50% width.
                  const ShimmerBlock(width: 100, height: 12),
                ],
              ],
            ),
          ),

          // Trailing block.
          if (hasTrailing) ...[
            SizedBox(width: spacing.space12),
            const ShimmerBlock(width: 60, height: 16),
          ],
        ],
      ),
    );
  }
}
