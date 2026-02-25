import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';
import 'button.dart';
import 'challenge_card.dart';

/// A category-colored reward card displaying points earned, progress, and
/// calculation breakdown for a challenge.
///
/// The card has two sections:
/// - **Top**: total earned, progress bar, calculation row, rank reward.
/// - **Bottom** (optional): epoch earned + action button. Only rendered when
///   [epochEarned] is non-null.
///
/// All text colors use `semantic.<category>.onColor` for correct contrast in
/// both light and dark mode.
class ChallengeRewardCard extends StatelessWidget {
  const ChallengeRewardCard({
    super.key,
    required this.category,
    required this.totalEarned,
    required this.progressFraction,
    required this.successRate,
    required this.maxPoints,
    required this.totalPoints,
    required this.rankReward,
    this.epochEarned,
    this.epochLabel,
    this.onEpochTap,
  });

  /// Challenge category — drives background color via [AppSemanticColors].
  final ChallengeCategory category;

  /// Formatted total points earned, e.g. "10,550.1".
  final String totalEarned;

  /// Progress bar fill fraction, 0.0–1.0.
  final double progressFraction;

  /// Formatted success rate, e.g. "98%".
  final String successRate;

  /// Formatted max points, e.g. "5,000".
  final String maxPoints;

  /// Formatted total points from calculation, e.g. "4,900".
  final String totalPoints;

  /// Formatted rank reward, e.g. "+0".
  final String rankReward;

  /// Formatted epoch earned points, e.g. "+50". When null the epoch section
  /// (divider + bottom half) is hidden.
  final String? epochEarned;

  /// Label for the epoch button, e.g. "View Epoch 176".
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
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final catColors = _categoryColors(semantic);

    final onColor = catColors.onColor;

    return Container(
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
                  'Total Earned',
                  style: textTheme.labelLarge?.copyWith(color: onColor),
                ),
                SizedBox(height: spacing.space4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        totalEarned,
                        style: textTheme.displaySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: onColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: spacing.space8),
                    Text(
                      'pts',
                      style: textTheme.titleLarge?.copyWith(color: onColor),
                    ),
                  ],
                ),
                SizedBox(height: spacing.space16),
                // Progress bar
                ClipRRect(
                  borderRadius: radii.borderRadiusFull,
                  child: SizedBox(
                    height: 6.0,
                    child: Stack(
                      children: [
                        // Track
                        Container(
                          color: onColor.withValues(alpha: 0.2),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: progressFraction.clamp(0.0, 1.0),
                          child: Container(color: onColor),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: spacing.space16),
                // Calculation row
                _CalculationRow(
                  successRate: successRate,
                  maxPoints: maxPoints,
                  totalPoints: totalPoints,
                  onColor: onColor,
                  textTheme: textTheme,
                  spacing: spacing,
                ),
                SizedBox(height: spacing.space8),
                // Rank reward row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOP 3 RANK REWARD',
                      style: textTheme.labelSmall?.copyWith(color: onColor),
                    ),
                    Text(
                      rankReward,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: onColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Optional epoch section
          if (epochEarned != null) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: onColor.withValues(alpha: 0.1),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.space16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Epoch Earned',
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
                                  fontFamily: 'monospace',
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

/// Internal widget: the "SUCCESS RATE × MAX PTS = TOTAL" calculation row.
class _CalculationRow extends StatelessWidget {
  const _CalculationRow({
    required this.successRate,
    required this.maxPoints,
    required this.totalPoints,
    required this.onColor,
    required this.textTheme,
    required this.spacing,
  });

  final String successRate;
  final String maxPoints;
  final String totalPoints;
  final Color onColor;
  final TextTheme textTheme;
  final AppSpacing spacing;

  @override
  Widget build(BuildContext context) {
    final labelStyle = textTheme.labelSmall?.copyWith(color: onColor);
    final valueStyle = textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      color: onColor,
    );

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SUCCESS RATE', style: labelStyle),
              Text(successRate, style: valueStyle),
            ],
          ),
        ),
        Text('×', style: textTheme.bodyMedium?.copyWith(color: onColor)),
        SizedBox(width: spacing.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MAX PTS', style: labelStyle),
              Text(maxPoints, style: valueStyle),
            ],
          ),
        ),
        Text('=', style: textTheme.bodyMedium?.copyWith(color: onColor)),
        SizedBox(width: spacing.space8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL', style: labelStyle),
              Text(totalPoints, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}
