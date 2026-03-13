import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/core/widgets/app_card.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import 'challenge_card.dart';
import 'challenge_category_icon.dart';
import 'top_app_bar.dart';

/// A named record for description sections in [ChallengeDetailPage].
typedef ChallengeDetailSection = ({String title, String body});

/// A full-page detail view for a blockchain challenge.
///
/// Renders a [TopAppBar] (large) with category icon, title, and subtitle,
/// followed by a reward card, description sections, and a total reward card.
///
/// This is a presentation-only widget: all data comes through constructor
/// parameters. The feature screen in `lib/features/` wires state to this widget.
class ChallengeDetailPage extends StatelessWidget {
  const ChallengeDetailPage({
    super.key,
    required this.title,
    required this.category,
    required this.dateRange,
    this.rewardCard,
    this.statusSection,
    required this.sections,
    this.totalRewardHeading,
    this.totalRewardBody,
    this.onBackTap,
  });

  /// Challenge title, e.g. "Produce Every Block".
  final String title;

  /// Challenge category — drives the icon in the app bar.
  final ChallengeCategory category;

  /// Subtitle text for the app bar, e.g. "Technical · Jan 12 - Jan 30".
  final String dateRange;

  /// The reward card widget (typically a [ChallengeRewardCard]).
  /// When null the reward section is hidden (e.g. missed / active challenges).
  final Widget? rewardCard;

  /// Optional status section inserted between reward card and text sections.
  /// Typically a [BlockProductionStatusCard] for produce-blocks challenges.
  final Widget? statusSection;

  /// Flexible list of description sections (e.g. Why, Task, Requirements).
  final List<ChallengeDetailSection> sections;

  /// Heading for the total reward card, e.g. "Total Reward Up to 6,500 pts".
  /// When null the total reward card is hidden.
  final String? totalRewardHeading;

  /// Body text for the total reward card. Ignored when [totalRewardHeading] is null.
  final String? totalRewardBody;

  /// Called when the back button is tapped.
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return CustomScrollView(
      slivers: [
        TopAppBar(
          title: title,
          size: TopAppBarSize.large,
          subtitle: dateRange,
          image: ChallengeCategoryIcon(category: category),
          onLeadingTap: onBackTap,
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: spacing.space16),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: spacing.space32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (rewardCard != null) ...[
                    rewardCard!,
                    SizedBox(height: spacing.space16),
                  ],
                  if (statusSection != null) ...[
                    statusSection!,
                    SizedBox(height: spacing.space16),
                  ],
                  _SectionsCard(sections: sections),
                  if (totalRewardHeading != null) ...[
                    SizedBox(height: spacing.space16),
                    _TotalRewardCard(
                      heading: totalRewardHeading!,
                      body: totalRewardBody ?? '',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white card rendering a flexible list of [ChallengeDetailSection]s.
class _SectionsCard extends StatelessWidget {
  const _SectionsCard({required this.sections});

  final List<ChallengeDetailSection> sections;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return AppCard(
      color: colors.surfaceContainerLowest,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            if (i > 0) SizedBox(height: spacing.space16),
            Text(
              sections[i].title,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
              ),
            ),
            SizedBox(height: spacing.space4),
            Text(
              sections[i].body,
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A white card with a reward formula heading and body text.
class _TotalRewardCard extends StatelessWidget {
  const _TotalRewardCard({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return AppCard(
      color: colors.surfaceContainerLowest,
      borderRadius: radii.borderRadiusLargeIncreased,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.space4,
        children: [
          Text(
            heading,
            style: textTheme.labelLarge?.copyWith(
              color: colors.onSurface,
            ),
          ),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
