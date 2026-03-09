import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/design_system/src/dropdown_chain.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_chip.dart';
import 'package:crypto_mobile_app/design_system/src/parallax_surface_layout.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_borders.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

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
    required this.scrollFractionNotifier,
    required this.onSeasonTap,
    required this.onEventTap,
    required this.seasonLabel,
    required this.eventLabel,
  });

  final double topPadding;
  final AppSpacing spacing;
  final ValueNotifier<double> scrollFractionNotifier;
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

    return ValueListenableBuilder<double>(
      valueListenable: scrollFractionNotifier,
      builder: (context, scrollFraction, child) {
        final bgColor = Color.lerp(
            colors.surface, colors.surfaceContainerLowest, scrollFraction)!;
        final borderColor = colors.outlineVariant;
        final chipBorder = Color.lerp(
            borderColor.withValues(alpha: 0), borderColor, scrollFraction)!;

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
                  variant: ChipVariant.surface,
                  borderColor: chipBorder,
                  onTap: onSeasonTap,
                ),
                DropdownChainItem(
                  label: eventLabel,
                  variant: ChipVariant.surface,
                  borderColor: chipBorder,
                  onTap: onEventTap,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool shouldRebuild(ChipBarDelegate oldDelegate) =>
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
    required this.scrollFractionNotifier,
    required this.badgeCounts,
  });

  final TabController tabController;
  final ValueNotifier<double> scrollFractionNotifier;
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

    return ValueListenableBuilder<double>(
      valueListenable: scrollFractionNotifier,
      builder: (context, scrollFraction, tabBar) {
        final cornerRadius = kSurfaceCornerRadius * (1.0 - scrollFraction);

        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(cornerRadius),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: tabBar,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(top: _kTopInset),
        child: _buildTabBar(context),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return TabBar(
      controller: tabController,
      labelColor: colors.onSurface,
      unselectedLabelColor: colors.outline,
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.titleSmall,
      indicatorColor: colors.primary,
      indicatorWeight: 3,
      dividerColor: colors.onSurface.withValues(alpha: borders.opacity),
      dividerHeight: borders.width,
      tabs: [
        for (int i = 0; i < kTabLabels.length; i++) _buildTab(context, i),
      ],
    );
  }

  Widget _buildTab(BuildContext context, int index) {
    final count = badgeCounts[index];
    if (count == 0) return Tab(text: kTabLabels[index]);

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
                  color: isActive
                      ? colors.onSurface
                      : colors.surfaceContainerHighest,
                  shape: const StadiumBorder(),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: textTheme.labelSmall?.copyWith(
                      color: isActive ? colors.surface : colors.outline,
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
      oldDelegate.tabController != tabController ||
      oldDelegate.badgeCounts != badgeCounts;
}
