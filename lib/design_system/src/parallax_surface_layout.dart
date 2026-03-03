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
class ParallaxSurfaceLayout extends StatefulWidget {
  const ParallaxSurfaceLayout({
    super.key,
    required this.header,
    required this.surfaceBody,
    this.headerHeight = kDefaultHeaderHeight,
    this.onRefresh,
  });

  /// Content centered in the fixed-height parallax area.
  final Widget header;

  /// Content inside the white surface container.
  final Widget surfaceBody;

  /// Height of the transparent spacer revealing the header.
  final double headerHeight;

  /// Pull-to-refresh callback. When null, no [RefreshIndicator] is shown.
  final RefreshCallback? onRefresh;

  @override
  State<ParallaxSurfaceLayout> createState() => _ParallaxSurfaceLayoutState();
}

class _ParallaxSurfaceLayoutState extends State<ParallaxSurfaceLayout> {
  final _scrollFraction = ValueNotifier<double>(0.0);

  @override
  void dispose() {
    _scrollFraction.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final fraction =
        (notification.metrics.pixels / widget.headerHeight).clamp(0.0, 1.0);
    if (fraction != _scrollFraction.value) {
      _scrollFraction.value = fraction;
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
            valueListenable: _scrollFraction,
            builder: (context, sf, child) {
              return Transform.translate(
                offset: Offset(0, -sf * widget.headerHeight * kParallaxRatio),
                child: child,
              );
            },
            child: SizedBox(
              height: widget.headerHeight,
              child: Center(child: widget.header),
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
        // Transparent spacer — reveals header behind
        SliverToBoxAdapter(
          child: SizedBox(height: widget.headerHeight),
        ),

        // Surface container with animated corner radius
        SliverToBoxAdapter(
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollFraction,
            builder: (context, sf, child) {
              final radius = kSurfaceCornerRadius * (1.0 - sf);
              return Container(
                clipBehavior: radius > 0 ? Clip.hardEdge : Clip.none,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: radius > 0
                      ? BorderRadius.vertical(
                          top: Radius.circular(radius),
                        )
                      : null,
                ),
                child: child,
              );
            },
            child: widget.surfaceBody,
          ),
        ),
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
}
