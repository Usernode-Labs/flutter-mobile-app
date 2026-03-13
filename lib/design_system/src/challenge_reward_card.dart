import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'button.dart';
import 'challenge_card.dart';

// ---------------------------------------------------------------------------
// Sealed reward data variants
// ---------------------------------------------------------------------------

/// Determines which middle section the [ChallengeRewardCard] renders.
sealed class ChallengeRewardData {
  const ChallengeRewardData();
}

/// Simple reward: shows only "Earned" + total points. No progress bar,
/// no calculation row, no top-3 rank.
class SimpleRewardData extends ChallengeRewardData {
  const SimpleRewardData();
}

/// Produce-blocks reward: shows progress bar, success-rate × max-pts
/// calculation row, and optional top-3 rank row.
class ProduceBlocksRewardData extends ChallengeRewardData {
  const ProduceBlocksRewardData({
    required this.progressFraction,
    required this.successRate,
    required this.maxPoints,
    required this.totalPoints,
    this.rankLabel,
    required this.rankReward,
    this.rateLabel = 'SUCCESS RATE',
  });

  /// Progress bar fill fraction, 0.0–1.0.
  final double progressFraction;

  /// Formatted success rate, e.g. "98%".
  final String successRate;

  /// Formatted max points, e.g. "5,000".
  final String maxPoints;

  /// Formatted total points from calculation, e.g. "4,900".
  final String totalPoints;

  /// Optional ordinal rank label, e.g. "1st", "2nd", "3rd".
  final String? rankLabel;

  /// Formatted rank reward, e.g. "+0".
  final String rankReward;

  /// Label for the rate row, e.g. "BLOCK RATE" mid-event or "SUCCESS RATE"
  /// when the event is completed.
  final String rateLabel;
}

// ---------------------------------------------------------------------------
// ChallengeRewardCard
// ---------------------------------------------------------------------------

/// A category-colored reward card displaying points earned for a challenge.
///
/// The card layout depends on [data]:
/// - [SimpleRewardData]: "Earned" label + total points only.
/// - [ProduceBlocksRewardData]: "Total Earned" label, progress bar, calculation
///   row, and rank reward row.
///
/// Both variants share the optional epoch section at the bottom (controlled by
/// [epochEarned] null-check).
class ChallengeRewardCard extends StatelessWidget {
  const ChallengeRewardCard({
    super.key,
    required this.category,
    required this.totalEarned,
    required this.data,
    this.epochSectionLabel,
    this.epochEarned,
    this.epochLabel,
    this.onEpochTap,
  });

  /// Challenge category — drives background color via [AppSemanticColors].
  final ChallengeCategory category;

  /// Formatted total points earned, e.g. "10,550.1".
  final String totalEarned;

  /// Variant-specific data that controls the middle section.
  final ChallengeRewardData data;

  /// Label for the epoch section heading, e.g. "Last 24h" or "This Epoch Earned".
  /// Defaults to "This Epoch Earned" when null.
  final String? epochSectionLabel;

  /// Formatted epoch earned points, e.g. "+50". When null the epoch section
  /// (divider + bottom half) is hidden.
  final String? epochEarned;

  /// Label for the epoch button, e.g. "View Details".
  final String? epochLabel;

  /// Called when the epoch button is tapped.
  final VoidCallback? onEpochTap;

  SemanticColorGroup _categoryColors(AppSemanticColors semantic) {
    return switch (category) {
      ChallengeCategory.technical => semantic.technical,
      ChallengeCategory.community => semantic.community,
      ChallengeCategory.flash => semantic.flash,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final catColors = _categoryColors(semantic);

    final onColor = catColors.onColor;
    final dimOnColor = onColor.withValues(alpha: 0.8);

    const headerLabel = 'Total Earned';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: catColors.color,
        borderRadius: radii.borderRadiusLargeIncreased,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top section
          Padding(
            padding: EdgeInsets.all(spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerLabel,
                  style: textTheme.labelLarge?.copyWith(color: onColor),
                ),
                SizedBox(height: spacing.space8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        totalEarned,
                        style: textTheme.displaySmall?.copyWith(
                          fontFamily: kMonoFontFamily,
                          color: onColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacing.space4),
                    Text(
                      'pts',
                      style: textTheme.titleLarge?.copyWith(color: onColor),
                    ),
                  ],
                ),

                // Variant-specific middle section
                if (data
                    case ProduceBlocksRewardData(
                      :final progressFraction,
                      :final successRate,
                      :final maxPoints,
                      :final totalPoints,
                      :final rankLabel,
                      :final rankReward,
                      :final rateLabel,
                    )) ...[
                  SizedBox(height: spacing.space24),
                  // Progress bar
                  ClipRRect(
                    borderRadius: radii.borderRadiusFull,
                    child: LinearProgressIndicator(
                      value: progressFraction.clamp(0.0, 1.0),
                      minHeight: 6.0,
                      backgroundColor: onColor.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(onColor),
                    ),
                  ),
                  SizedBox(height: spacing.space16),
                  // Calculation row
                  _CalculationRow(
                    rateLabel: rateLabel,
                    successRate: successRate,
                    maxPoints: maxPoints,
                    totalPoints: totalPoints,
                    onColor: onColor,
                    dimOnColor: dimOnColor,
                  ),
                  SizedBox(height: spacing.space12),
                  // Rank reward row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOP 3 RANK REWARD',
                            style: textTheme.labelSmall
                                ?.copyWith(color: dimOnColor),
                          ),
                          if (rankLabel != null) ...[
                            SizedBox(width: spacing.space8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: spacing.space8,
                                vertical: spacing.space4,
                              ),
                              decoration: BoxDecoration(
                                color: onColor.withValues(alpha: 0.15),
                                borderRadius: radii.borderRadiusFull,
                              ),
                              child: Text(
                                rankLabel,
                                style: textTheme.labelSmall
                                    ?.copyWith(color: onColor),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        rankReward,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: kMonoFontFamily,
                          color: onColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Optional epoch section
          if (epochEarned != null) ...[
            Divider(
              height: borders.width,
              thickness: borders.width,
              color: onColor.withValues(alpha: borders.opacity),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    epochSectionLabel ?? 'This Epoch Earned',
                    style: textTheme.labelLarge?.copyWith(color: onColor),
                  ),
                  SizedBox(height: spacing.space8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                epochEarned!,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontFamily: kMonoFontFamily,
                                  color: onColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: spacing.space4),
                            Text(
                              'pts',
                              style: textTheme.titleMedium
                                  ?.copyWith(color: onColor),
                            ),
                          ],
                        ),
                      ),
                      if (epochLabel != null)
                        Button(
                          variant: ButtonVariant.surface,
                          size: ButtonSize.small,
                          label: epochLabel!,
                          onTap: onEpochTap,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal widget: the "BLOCK RATE × MAX PTS = TOTAL" calculation row.
class _CalculationRow extends StatelessWidget {
  const _CalculationRow({
    required this.rateLabel,
    required this.successRate,
    required this.maxPoints,
    required this.totalPoints,
    required this.onColor,
    required this.dimOnColor,
  });

  final String rateLabel;
  final String successRate;
  final String maxPoints;
  final String totalPoints;
  final Color onColor;
  final Color dimOnColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final labelStyle = textTheme.labelSmall?.copyWith(color: dimOnColor);
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontFamily: kMonoFontFamily,
      color: onColor,
    );
    final operatorStyle = textTheme.bodyMedium?.copyWith(color: onColor);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left group: successRate × maxPts
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rateLabel,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(successRate, style: valueStyle),
                  ],
                ),
              ),
              SizedBox(width: spacing.space12),
              Text('×', style: operatorStyle),
              SizedBox(width: spacing.space12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAX PTS', style: labelStyle),
                  Text(maxPoints, style: valueStyle),
                ],
              ),
            ],
          ),
        ),
        // Right group: = total
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('=', style: operatorStyle),
            SizedBox(width: spacing.space12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TOTAL', style: labelStyle),
                Text(totalPoints, style: valueStyle),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
