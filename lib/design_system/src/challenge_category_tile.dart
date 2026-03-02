import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

/// A single sub-challenge item within a [ChallengeCategoryTile].
class ChallengeCategoryItem {
  const ChallengeCategoryItem({
    required this.title,
    required this.isCompleted,
    this.onTap,
  });

  final String title;
  final bool isCompleted;
  final VoidCallback? onTap;
}

/// An expandable list tile that groups sub-challenges by category.
///
/// Shows a category icon, name, remaining/completed counts, and total points.
/// Expands to reveal individual challenge chips styled as completed (disabled)
/// or remaining (active tonal).
///
/// Built on M3 [ExpansionTile] — inherits header layout from [ListTileThemeData]
/// and expansion styling from [ExpansionTileThemeData].
///
/// Presentation-only — takes all state via constructor params.
class ChallengeCategoryTile extends StatefulWidget {
  const ChallengeCategoryTile({
    super.key,
    required this.categoryIcon,
    required this.categoryName,
    required this.remainingCount,
    required this.completedCount,
    required this.pointsLabel,
    required this.challenges,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  /// Leading icon widget (e.g. [ChallengeCategoryIcon]).
  final Widget categoryIcon;

  /// Category display name, e.g. "Technical".
  final String categoryName;

  /// Number of remaining (active) challenges.
  final int remainingCount;

  /// Number of completed challenges.
  final int completedCount;

  /// Formatted points string, e.g. "4,525 pts".
  final String pointsLabel;

  /// Sub-challenge items to show when expanded.
  final List<ChallengeCategoryItem> challenges;

  /// Whether the tile starts expanded.
  final bool initiallyExpanded;

  /// Called when expansion state changes.
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<ChallengeCategoryTile> createState() => _ChallengeCategoryTileState();
}

class _ChallengeCategoryTileState extends State<ChallengeCategoryTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;

    return ExpansionTile(
      leading: SizedBox(
        width: sizing.iconContainerSmall,
        height: sizing.iconContainerSmall,
        child: widget.categoryIcon,
      ),
      title: Text(
        widget.categoryName,
        style: textTheme.titleSmall?.copyWith(
          color: colors.onSurface,
        ),
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${widget.remainingCount} Remaining',
              style: textTheme.bodySmall?.copyWith(
                color: colors.primary,
              ),
            ),
            TextSpan(
              text: ' · ',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: opacity.secondary),
              ),
            ),
            TextSpan(
              text: '${widget.completedCount} Completed',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withValues(alpha: opacity.disabled),
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.pointsLabel,
            style: textTheme.labelMedium?.copyWith(
              fontFamily: 'IBMPlexMono',
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(width: spacing.space4),
          AnimatedRotation(
            turns: _isExpanded ? 0.0 : -0.25,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              Symbols.expand_more,
              size: sizing.iconSmall,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      initiallyExpanded: widget.initiallyExpanded,
      onExpansionChanged: (expanded) {
        setState(() {
          _isExpanded = expanded;
        });
        widget.onExpansionChanged?.call(expanded);
      },
      children: [_buildBody(context)],
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return Padding(
      // icon container + gap = indent to align with title text
      padding: EdgeInsets.only(
        left: sizing.iconContainerSmall + spacing.space12,
        bottom: spacing.space12,
      ),
      child: Wrap(
        spacing: spacing.space8,
        runSpacing: spacing.space8,
        children: [
          for (final challenge in widget.challenges)
            _ChallengeChip(
              label: challenge.title,
              isCompleted: challenge.isCompleted,
              onTap: challenge.onTap,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChallengeChip — tonal chip for completed/remaining challenges
// ---------------------------------------------------------------------------

class _ChallengeChip extends StatelessWidget {
  const _ChallengeChip({
    required this.label,
    required this.isCompleted,
    this.onTap,
  });

  final String label;
  final bool isCompleted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final opacity = Theme.of(context).extension<AppOpacity>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    if (isCompleted) {
      // Completed: disabled style
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.space12,
            vertical: spacing.space8,
          ),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: opacity.subtle),
            borderRadius: radii.borderRadiusSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: spacing.space4,
            children: [
              Icon(
                Symbols.check_box,
                size: 16,
                color: colors.onSurface.withValues(alpha: opacity.disabled),
              ),
              Text(
                label,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurface.withValues(alpha: opacity.disabled),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Remaining: primary filled style
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space12,
          vertical: spacing.space8,
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: radii.borderRadiusSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.space4,
          children: [
            Icon(
              Symbols.check_box_outline_blank,
              size: 16,
              color: colors.onPrimary,
            ),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
