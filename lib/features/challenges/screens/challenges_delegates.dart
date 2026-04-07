import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/design_system/src/parallax_surface_layout.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_borders.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';

/// M3 TabBar height.
const kTabBarHeight = 48.0;

/// Tab labels.
const kTabLabels = ['Active', 'Completed', 'Missed'];

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
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: scrollFractionNotifier,
      builder: (context, scrollFraction, tabBar) {
        final cornerRadius = kSurfaceCornerRadius * (1.0 - scrollFraction);

        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borders = theme.extension<AppBorders>()!;

    return TabBar(
      controller: tabController,
      labelColor: colorScheme.onSurface,
      unselectedLabelColor: colorScheme.outline,
      labelStyle: theme.textTheme.titleSmall,
      unselectedLabelStyle: theme.textTheme.titleSmall,
      indicatorColor: colorScheme.primary,
      indicatorWeight: 3,
      dividerColor: colorScheme.onSurface.withValues(alpha: borders.opacity),
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
  bool shouldRebuild(SurfaceTabBarDelegate oldDelegate) => true;
}
