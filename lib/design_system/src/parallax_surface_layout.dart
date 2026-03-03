import 'package:flutter/material.dart';

/// Parallax speed ratio — header moves at 40 % of scroll speed.
const kParallaxRatio = 0.4;

/// Maximum corner radius of the surface container at rest.
const kSurfaceCornerRadius = 28.0;

/// Default header height for the parallax spacer.
const kDefaultHeaderHeight = 200.0;

/// A layout that places a fixed [header] behind a scrolling surface container.
///
/// As the user scrolls, the header translates upward at [kParallaxRatio] of the
/// scroll speed, while the surface container's top corners animate from
/// [kSurfaceCornerRadius] to zero.
///
/// When [onRefresh] is provided the scroll view is wrapped in a
/// [RefreshIndicator].
///
/// When [pinnedHeaderSliver] is provided it is inserted as the first sliver
/// (before the transparent spacer), creating a pinned bar that stays visible
/// while the rest of the content scrolls.  Use [pinnedHeaderHeight] to offset
/// the parallax header downward so it doesn't overlap.
///
/// When [scrollFractionNotifier] is provided the layout writes the scroll
/// fraction (0.0 – 1.0) to that notifier so external delegates can react to
/// scroll position.  When null, an internal notifier is used.
class ParallaxSurfaceLayout extends StatefulWidget {
  const ParallaxSurfaceLayout({
    super.key,
    required this.header,
    required this.surfaceBody,
    this.headerHeight = kDefaultHeaderHeight,
    this.onRefresh,
    this.pinnedHeaderSliver,
    this.pinnedHeaderHeight = 0.0,
    this.scrollFractionNotifier,
    this.surfaceFillsViewport = false,
  });

  /// Content centered in the fixed-height parallax area.
  final Widget header;

  /// Content inside the white surface container.
  final Widget surfaceBody;

  /// Height of the transparent spacer revealing the header.
  final double headerHeight;

  /// Pull-to-refresh callback. When null, no [RefreshIndicator] is shown.
  final RefreshCallback? onRefresh;

  /// A sliver (e.g. [SliverPersistentHeader]) inserted before the spacer.
  final Widget? pinnedHeaderSliver;

  /// Height of the pinned header — offsets the parallax header downward.
  final double pinnedHeaderHeight;

  /// Externally-provided notifier. When set, the layout writes scroll fraction
  /// to it. When null, an internal notifier is used.
  final ValueNotifier<double>? scrollFractionNotifier;

  /// When true, the surface background is stretched to viewport height (so
  /// there is scroll distance even when the body is small) and the [surfaceBody]
  /// is constrained to the initially-visible portion of the surface so that
  /// centering widgets like [Center] appear in the visible area, not in the
  /// middle of the full viewport-tall container.
  final bool surfaceFillsViewport;

  @override
  State<ParallaxSurfaceLayout> createState() => _ParallaxSurfaceLayoutState();
}

class _ParallaxSurfaceLayoutState extends State<ParallaxSurfaceLayout> {
  final _internalNotifier = ValueNotifier<double>(0.0);

  ValueNotifier<double> get _effectiveNotifier =>
      widget.scrollFractionNotifier ?? _internalNotifier;

  @override
  void dispose() {
    _internalNotifier.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final fraction =
        (notification.metrics.pixels / widget.headerHeight).clamp(0.0, 1.0);
    if (fraction != _effectiveNotifier.value) {
      _effectiveNotifier.value = fraction;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Layer 1: Header (parallax)
          ValueListenableBuilder<double>(
            valueListenable: _effectiveNotifier,
            builder: (context, sf, child) {
              return Transform.translate(
                offset: Offset(0, -sf * widget.headerHeight * kParallaxRatio),
                child: child,
              );
            },
            child: Padding(
              padding: EdgeInsets.only(top: widget.pinnedHeaderHeight),
              child: SizedBox(
                height: widget.headerHeight,
                child: Center(child: widget.header),
              ),
            ),
          ),

          // Layer 2: Scrolling content surface
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _buildScrollView(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollView(ThemeData theme) {
    final scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Pinned header (if provided)
        if (widget.pinnedHeaderSliver != null) widget.pinnedHeaderSliver!,

        // Transparent spacer — reveals header behind
        SliverToBoxAdapter(
          child: SizedBox(height: widget.headerHeight),
        ),

        // Surface container with animated corner radius
        _buildSurfaceSliver(theme),
      ],
    );

    if (widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: scrollView,
      );
    }

    return scrollView;
  }

  Widget _buildDecoratedSurface(ThemeData theme, Widget body) {
    return ValueListenableBuilder<double>(
      valueListenable: _effectiveNotifier,
      builder: (context, sf, child) {
        final radius = kSurfaceCornerRadius * (1.0 - sf);
        return Container(
          clipBehavior: radius > 0 ? Clip.hardEdge : Clip.none,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: radius > 0
                ? BorderRadius.vertical(top: Radius.circular(radius))
                : null,
          ),
          child: child,
        );
      },
      child: body,
    );
  }

  Widget _buildSurfaceSliver(ThemeData theme) {
    if (!widget.surfaceFillsViewport) {
      return SliverToBoxAdapter(
        child: _buildDecoratedSurface(theme, widget.surfaceBody),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.viewportMainAxisExtent;
        final visibleSurfaceHeight =
            viewportHeight - widget.headerHeight - widget.pinnedHeaderHeight;
        return SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewportHeight),
            child: _buildDecoratedSurface(
              theme,
              // Align loosens the ConstrainedBox's minHeight so SizedBox
              // can shrink to visibleSurfaceHeight for correct centering.
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: visibleSurfaceHeight,
                  child: widget.surfaceBody,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
