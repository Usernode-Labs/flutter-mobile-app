import 'package:flutter/material.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_spacing.dart';

/// Data class for a single tab definition.
class TabItem {
  /// Creates a tab item with a [label] and optional [badgeCount].
  const TabItem({
    required this.label,
    this.badgeCount,
  });

  /// The tab label text.
  final String label;

  /// Badge count displayed inline after the label.
  /// Null or 0 means no badge is shown.
  final int? badgeCount;
}

/// A tab view backed by M3 [TabBar] (primary style) + [TabBarView].
///
/// Combines a primary tab bar (labels, optional inline badges, underline
/// indicator, and divider) with a swipeable content area.
///
/// Two layout modes controlled by [isScrollable]:
/// - **Fixed** (default): equal-width tabs fill the bar.
/// - **Scrollable**: natural-width tabs in a horizontal scroll view.
///
/// Manages selection state internally and notifies the parent via
/// [onTabChanged].
class Tabs extends StatefulWidget {
  /// Creates a tab view with the given [tabs] and [children].
  ///
  /// [tabs] and [children] must have the same length.
  const Tabs({
    super.key,
    required this.tabs,
    required this.children,
    this.initialIndex = 0,
    this.onTabChanged,
    this.isScrollable = false,
    this.showDivider = true,
  }) : assert(
          tabs.length == children.length,
          'tabs and children must have the same length',
        );

  /// Tab definitions (label + optional badge count).
  final List<TabItem> tabs;

  /// Content widget for each tab. Must match [tabs] length.
  final List<Widget> children;

  /// Starting tab index.
  final int initialIndex;

  /// Called when the selected tab changes (tap or swipe).
  final ValueChanged<int>? onTabChanged;

  /// When true, tabs have natural width in a scrollable row.
  /// When false (default), tabs have equal width filling the bar.
  final bool isScrollable;

  /// Whether to show the divider line below the tab bar.
  /// Defaults to true.
  final bool showDivider;

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    widget.onTabChanged?.call(_tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borders = Theme.of(context).extension<AppBorders>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: widget.isScrollable,
          tabAlignment: widget.isScrollable ? TabAlignment.start : null,
          labelColor: colors.onSurface,
          unselectedLabelColor: colors.outline,
          labelStyle: textTheme.titleSmall,
          unselectedLabelStyle: textTheme.titleSmall,
          indicatorColor: colors.primary,
          indicatorWeight: 3,
          dividerColor: widget.showDivider
              ? colors.onSurface.withValues(alpha: borders.opacity)
              : Colors.transparent,
          dividerHeight: widget.showDivider ? borders.width : 0,
          tabs: [
            for (int i = 0; i < widget.tabs.length; i++) _buildTab(i),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.children,
          ),
        ),
      ],
    );
  }

  Widget _buildTab(int index) {
    final tab = widget.tabs[index];
    final hasBadge = tab.badgeCount != null && tab.badgeCount! > 0;

    if (!hasBadge) return Tab(text: tab.label);

    return Tab(
      child: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;
          final spacing = Theme.of(context).extension<AppSpacing>()!;
          final isActive = _tabController.index == index;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tab.label,
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
                    '${tab.badgeCount}',
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
}
