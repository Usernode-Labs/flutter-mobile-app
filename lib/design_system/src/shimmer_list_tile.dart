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
          // Leading — 48px box with 40px circle matches IconBadge's
          // 3-layer default (48px container, 40px surface).
          SizedBox(
            width: sizing.iconContainerRegular,
            height: sizing.iconContainerRegular,
            child: Center(
              child: ShimmerBlock(
                width: sizing.iconContainerSmall,
                height: sizing.iconContainerSmall,
                borderRadius: radii.borderRadiusFull,
              ),
            ),
          ),
          SizedBox(width: spacing.space16),

          // Title + subtitle lines — proportional widths.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line — ~55% width.
                const FractionallySizedBox(
                  widthFactor: 0.55,
                  child: ShimmerBlock(width: double.infinity, height: 14),
                ),
                SizedBox(height: spacing.space8),
                // Subtitle line 1 — ~75% width.
                const FractionallySizedBox(
                  widthFactor: 0.75,
                  child: ShimmerBlock(width: double.infinity, height: 12),
                ),
                if (isThreeLine) ...[
                  SizedBox(height: spacing.space4),
                  // Subtitle line 2 — ~40% width.
                  const FractionallySizedBox(
                    widthFactor: 0.40,
                    child: ShimmerBlock(width: double.infinity, height: 12),
                  ),
                ],
              ],
            ),
          ),

          // Trailing — two blocks matching real trailing structure
          // (amount text + timestamp/badge).
          if (hasTrailing) ...[
            SizedBox(width: spacing.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const ShimmerBlock(width: 60, height: 14),
                SizedBox(height: spacing.space4),
                const ShimmerBlock(width: 48, height: 12),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
