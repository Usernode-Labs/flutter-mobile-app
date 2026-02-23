import 'package:flutter/material.dart';

import '../tokens/app_animation.dart';
import '../tokens/app_radii.dart';
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

/// A complete tab view built from primitives.
///
/// Combines a tab bar (labels, optional inline badges, a sliding active
/// indicator, and a divider) with a swipeable [PageView] content area.
///
/// Two layout modes controlled by [isScrollable]:
/// - **Fixed** (default): equal-width tabs fill the bar.
/// - **Scrollable**: natural-width tabs in a horizontal scroll view.
///
/// Manages selection state internally and notifies the parent via
/// [onTabChanged]. The indicator slides smoothly between tabs on both
/// tap and swipe — driven by the [PageView] scroll position.
///
/// Built bottom-up from [GestureDetector], [Container], [Row], [Text],
/// and [PageView]. No Material Tab classes.
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

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  late int _selectedIndex;
  late PageController _pageController;
  double _pagePosition = 0;
  bool _indexIsChanging = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    _pagePosition = _selectedIndex.toDouble();
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (_pageController.hasClients && _pageController.page != null) {
      setState(() {
        _pagePosition = _pageController.page!;
        // M3 pattern: don't override _selectedIndex during tap animation.
        if (!_indexIsChanging) {
          _selectedIndex = _pagePosition.round();
        }
      });
    }
  }

  void _onTabTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      _indexIsChanging = true;
    });
    final animation = Theme.of(context).extension<AppAnimation>()!;
    _pageController
        .animateToPage(
          index,
          duration: animation.complex,
          curve: Curves.easeInOut,
        )
        .then((_) => _indexIsChanging = false);
  }

  void _onPageChanged(int index) {
    _indexIsChanging = false;
    setState(() {
      _selectedIndex = index;
    });
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48, // M3 kTextTabBarHeight
          child: widget.isScrollable
              ? _buildScrollableTabBar()
              : _buildFixedTabBar(),
        ),
        Container(height: 1, color: colors.outlineVariant),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: widget.children,
          ),
        ),
      ],
    );
  }

  // ── Fixed tab bar ──

  Widget _buildFixedTabBar() {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / widget.tabs.length;

        return Stack(
          children: [
            Row(
              children: [
                for (int i = 0; i < widget.tabs.length; i++)
                  Expanded(child: _buildTabLabel(i)),
              ],
            ),
            Positioned(
              bottom: 0,
              left: _pagePosition * tabWidth + 2, // 2px Figma inset
              width: tabWidth - 4,
              height: 3, // M3 indicator weight
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radii.full),
                    topRight: Radius.circular(radii.full),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Scrollable tab bar ──

  Widget _buildScrollableTabBar() {
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < widget.tabs.length; i++)
            GestureDetector(
              onTap: () => _onTabTapped(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.space16,
                        ),
                        child: _buildLabelRow(i),
                      ),
                    ),
                    if (_selectedIndex == i)
                      Positioned(
                        bottom: 0,
                        left: 2,
                        right: 2,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(radii.full),
                              topRight: Radius.circular(radii.full),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared builders ──

  Widget _buildTabLabel(int index) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Center(child: _buildLabelRow(index)),
    );
  }

  Widget _buildLabelRow(int index) {
    final tab = widget.tabs[index];
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final isActive = _selectedIndex == index;
    final hasBadge = tab.badgeCount != null && tab.badgeCount! > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            tab.label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: textTheme.titleSmall?.copyWith(
              color: isActive ? colors.onSurface : colors.outline,
            ),
          ),
        ),
        if (hasBadge) ...[
          SizedBox(width: spacing.space4),
          Container(
            height: 16, // M3 badge largeSize
            constraints: const BoxConstraints(minWidth: 16),
            padding: EdgeInsets.symmetric(horizontal: spacing.space4),
            decoration: ShapeDecoration(
              color: isActive ? colors.onSurface : colors.outline,
              shape: const StadiumBorder(),
            ),
            child: Center(
              child: Text(
                '${tab.badgeCount}',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.surface,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
