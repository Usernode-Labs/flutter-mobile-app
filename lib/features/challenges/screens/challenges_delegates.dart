import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_chain.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// Spacer height matching ScoreHeader's natural size.
const kChallengesSpacerHeight = 344.0;

/// M3 TabBar height.
const kTabBarHeight = 48.0;

/// Chip row intrinsic height.
const kChipHeight = 32.0;

/// Tab labels.
const kTabLabels = ['Active', 'Completed', 'Missed'];

// ---------------------------------------------------------------------------
// ChipBarDelegate — pinned DropdownChain with lerping background
// ---------------------------------------------------------------------------

class ChipBarDelegate extends SliverPersistentHeaderDelegate {
  ChipBarDelegate({
    required this.topPadding,
    required this.spacing,
    required this.scrollFraction,
    required this.onSeasonTap,
    required this.onEventTap,
    required this.seasonLabel,
    required this.eventLabel,
  });

  final double topPadding;
  final AppSpacing spacing;
  final double scrollFraction;
  final VoidCallback onSeasonTap;
  final VoidCallback onEventTap;
  final String seasonLabel;
  final String eventLabel;

  @override
  double get maxExtent =>
      topPadding + spacing.space8 + kChipHeight + spacing.space8;

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    final bgColor = Color.lerp(
        colors.surfaceContainerLowest.withValues(alpha: 0),
        colors.surfaceContainerLowest,
        scrollFraction)!;
    final chipBorder = Color.lerp(colors.outlineVariant.withValues(alpha: 0),
        colors.outlineVariant, scrollFraction)!;

    return ColoredBox(
      color: bgColor,
      child: Padding(
        padding: EdgeInsets.only(
          top: topPadding + spacing.space8,
          left: spacing.space16,
          right: spacing.space16,
          bottom: spacing.space8,
        ),
        child: DropdownChain(
          items: [
            DropdownChainItem(
              label: seasonLabel,
              selected: true,
              borderColor: chipBorder,
              onTap: onSeasonTap,
            ),
            DropdownChainItem(
              label: eventLabel,
              selected: true,
              borderColor: chipBorder,
              onTap: onEventTap,
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(ChipBarDelegate oldDelegate) =>
      oldDelegate.scrollFraction != scrollFraction ||
      oldDelegate.topPadding != topPadding ||
      oldDelegate.seasonLabel != seasonLabel ||
      oldDelegate.eventLabel != eventLabel;
}

// ---------------------------------------------------------------------------
// SurfaceTabBarDelegate — pinned white surface with animating corner radius
// ---------------------------------------------------------------------------

class SurfaceTabBarDelegate extends SliverPersistentHeaderDelegate {
  SurfaceTabBarDelegate({
    required this.tabController,
    required this.scrollFraction,
    required this.badgeCounts,
  });

  final TabController tabController;
  final double scrollFraction;
  final List<int> badgeCounts;

  static const _kTopInset = 8.0;

  @override
  double get maxExtent => _kTopInset + kTabBarHeight;

  @override
  double get minExtent => _kTopInset + kTabBarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cornerRadius = 28.0 * (1.0 - scrollFraction);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(cornerRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(top: _kTopInset),
        child: TabBar(
          controller: tabController,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.outline,
          labelStyle: textTheme.titleSmall,
          unselectedLabelStyle: textTheme.titleSmall,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          dividerColor: colors.outlineVariant,
          dividerHeight: 1,
          tabs: [
            for (int i = 0; i < kTabLabels.length; i++) _buildTab(context, i),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final badge = badgeCounts[index];
    if (badge <= 0) return Tab(text: kTabLabels[index]);

    return Tab(
      child: ListenableBuilder(
        listenable: tabController,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final isActive = tabController.index == index;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  kTabLabels[index],
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              SizedBox(width: spacing.space4),
              Container(
                height: 16,
                constraints: const BoxConstraints(minWidth: 16),
                padding: EdgeInsets.symmetric(horizontal: spacing.space4),
                decoration: ShapeDecoration(
                  color: isActive ? colors.onSurface : colors.outline,
                  shape: const StadiumBorder(),
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.surface,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(SurfaceTabBarDelegate oldDelegate) =>
      oldDelegate.scrollFraction != scrollFraction ||
      oldDelegate.tabController != tabController ||
      oldDelegate.badgeCounts != badgeCounts;
}
