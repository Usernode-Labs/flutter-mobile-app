import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import 'shimmer_block.dart';

/// A skeleton placeholder shaped like a [ChallengeCard] with header, title,
/// description, and reward lines.
///
/// Composes [ShimmerBlock] instances inside a bordered [Container] to match
/// the visual structure of a challenge card, giving users spatial context
/// during data loading.
class ShimmerCardSkeleton extends StatelessWidget {
  const ShimmerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: radii.borderRadiusLargeIncreased,
        border: Border.all(color: colors.outlineVariant),
      ),
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header line — ~40%.
          const FractionallySizedBox(
            widthFactor: 0.40,
            child: ShimmerBlock(width: double.infinity, height: 12),
          ),
          SizedBox(height: spacing.space12),
          // Title line — ~65%.
          const FractionallySizedBox(
            widthFactor: 0.65,
            child: ShimmerBlock(width: double.infinity, height: 16),
          ),
          SizedBox(height: spacing.space8),
          // Description line — ~90%.
          const FractionallySizedBox(
            widthFactor: 0.90,
            child: ShimmerBlock(width: double.infinity, height: 12),
          ),
          SizedBox(height: spacing.space12),
          // Reward bar — ~30%.
          const FractionallySizedBox(
            widthFactor: 0.30,
            child: ShimmerBlock(width: double.infinity, height: 14),
          ),
        ],
      ),
    );
  }
}
