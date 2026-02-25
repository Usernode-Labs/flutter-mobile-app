import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

class ChallengeActivitySummary extends StatelessWidget {
  const ChallengeActivitySummary({
    super.key,
    required this.completedCount,
    required this.missedCount,
    required this.totalCount,
    this.onViewCompleted,
    this.onViewMissed,
  });

  final int completedCount;
  final int missedCount;
  final int totalCount;
  final VoidCallback? onViewCompleted;
  final VoidCallback? onViewMissed;

  String get _headline {
    if (completedCount > 0) return 'All caught up!';
    if (missedCount > 0) return 'No challenges completed';
    return 'No challenges yet';
  }

  String get _summary {
    if (totalCount > 0) {
      final tackled = completedCount + missedCount;
      return "You've tackled $tackled of $totalCount challenges this season.";
    }
    return 'Check back soon for new challenges.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radii.largeIncreased),
        border: Border.all(color: colors.outlineVariant, width: 1),
      ),
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headline,
            style: textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
            ),
          ),
          SizedBox(height: spacing.space8),
          Text(
            _summary,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space16),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  icon: Symbols.check_circle_sharp,
                  label: '$completedCount Done',
                  iconColor: colors.onSurface,
                  textColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerHigh,
                  borderRadius: radii.small,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewCompleted,
                ),
              ),
              SizedBox(width: spacing.space12),
              Expanded(
                child: _Pill(
                  icon: Symbols.event_busy_sharp,
                  label: '$missedCount Missed',
                  iconColor: colors.onSurfaceVariant,
                  textColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surfaceContainerHigh,
                  borderRadius: radii.small,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewMissed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderRadius,
    required this.spacing,
    required this.sizing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final double borderRadius;
  final AppSpacing spacing;
  final AppSizing sizing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space12,
        vertical: spacing.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: sizing.iconSmall,
            color: iconColor,
            weight: 300,
            opticalSize: 20,
          ),
          SizedBox(width: spacing.space4),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
