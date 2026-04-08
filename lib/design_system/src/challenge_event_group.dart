import 'package:flutter/material.dart';

import 'challenge_card.dart';
import 'challenge_category_icon.dart';
import '../tokens/app_borders.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';

/// A single challenge item within a [ChallengeEventGroup].
class ChallengeEventItem {
  const ChallengeEventItem({
    required this.title,
    required this.category,
    required this.variant,
    this.earnedPoints,
    this.onTap,
  });

  final String title;
  final ChallengeCategory category;
  final ChallengeCardVariant variant;

  /// Formatted earned points, e.g. "500 pts". Shown as trailing text.
  final String? earnedPoints;
  final VoidCallback? onTap;
}

/// A card that groups challenges by event.
///
/// All content is rendered as [ListTile]s — the header has no leading (title
/// at K₁ = 16dp), challenge rows have a category icon leading (title at
/// K₂ = 72dp). The keyline shift IS the visual hierarchy — no divider needed.
/// Points labels share the same trailing keyline for clean column alignment.
///
/// Follows the "When Zones Collide" pattern: Card provides vertical-only
/// inset (`space8`), ListTiles own their `contentPadding` (16h from theme).
///
/// Presentation-only — takes all state via constructor params.
class ChallengeEventGroup extends StatelessWidget {
  const ChallengeEventGroup({
    super.key,
    required this.eventName,
    this.dateRange,
    required this.pointsLabel,
    required this.challenges,
  });

  /// Event display name, e.g. "Block Production".
  final String eventName;

  /// Formatted date range, e.g. "Mar 1 – Mar 31".
  final String? dateRange;

  /// Formatted points string, e.g. "6,500 pts".
  final String pointsLabel;

  /// Challenge items rendered as flat rows inside the card.
  final List<ChallengeEventItem> challenges;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radii.largeIncreased),
        side: BorderSide(
          color: colors.outlineVariant,
          width: borders.width,
        ),
      ),
      // "When Zones Collide": vertical-only inset, ListTiles own horizontal.
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — no leading, title at K₁ (16dp from card edge).
            ListTile(
              title: Text(
                eventName,
                style: textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                ),
              ),
              subtitle: Text(
                [
                  if (dateRange != null) dateRange!,
                  '${challenges.length} challenge${challenges.length == 1 ? '' : 's'}',
                ].join(' · '),
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                pointsLabel,
                style: textTheme.labelMedium?.copyWith(
                  fontFamily: kMonoFontFamily,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            // Challenge rows — leading icon pushes title to K₂ (72dp).
            for (final challenge in challenges)
              _ChallengeRow(challenge: challenge),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChallengeRow — flat ListTile for challenge items inside the card
// ---------------------------------------------------------------------------

class _ChallengeRow extends StatelessWidget {
  const _ChallengeRow({required this.challenge});

  final ChallengeEventItem challenge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    final isMissed = challenge.variant == ChallengeCardVariant.missed;

    return ListTile(
      leading: SizedBox(
        width: sizing.iconContainerSmall,
        height: sizing.iconContainerSmall,
        child: ChallengeCategoryIcon(
          category: challenge.category,
          muted: isMissed,
        ),
      ),
      title: Text(
        challenge.title,
        style: textTheme.bodyMedium?.copyWith(
          color: isMissed
              ? colors.onSurface.withValues(alpha: opacity.disabled)
              : colors.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: challenge.earnedPoints != null
          ? Text(
              challenge.earnedPoints!,
              style: textTheme.labelMedium?.copyWith(
                fontFamily: kMonoFontFamily,
                color: isMissed
                    ? colors.onSurfaceVariant
                        .withValues(alpha: opacity.disabled)
                    : colors.onSurfaceVariant,
              ),
            )
          : null,
      onTap: challenge.onTap,
    );
  }
}
