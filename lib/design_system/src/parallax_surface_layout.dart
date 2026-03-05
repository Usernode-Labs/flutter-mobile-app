import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Parallax speed ratio — header moves at 40 % of scroll speed.
const kParallaxRatio = 0.4;

/// Maximum corner radius of the surface container at rest.
const kSurfaceCornerRadius = 28.0;

/// Default header height for the parallax spacer.
const kDefaultHeaderHeight = 200.0;

/// Standard screen header height — shared across screens that use the
/// parallax-header-plus-pinned-bar pattern (wallet, challenges, etc.).
const kScreenHeaderHeight = 344.0;

/// A layout that places a fixed [header] behind a scrolling surface container.
///
/// As the user scrolls, the header translates upward at [kParallaxRatio] of the
/// scroll speed, while the surface container's top corners animate from
/// [kSurfaceCornerRadius] to zero.
///
/// Provide [surfaceSlivers] for lazy sliver-based content. Use
/// [pinnedHeaderSlivers] for one or more pinned bars above the content.
///
/// When [scrollFractionNotifier] is provided the layout writes the scroll
/// fraction (0.0 – 1.0) to that notifier so external delegates can react to
/// scroll position.  When null, an internal notifier is used.
class ParallaxSurfaceLayout extends StatefulWidget {
  const ParallaxSurfaceLayout({
    super.key,
    required this.header,
    @Deprecated('Use surfaceSlivers') this.surfaceBody,
    this.surfaceSlivers,
    this.headerHeight = kDefaultHeaderHeight,
    this.onRefresh,
    @Deprecated('Use pinnedHeaderSlivers') this.pinnedHeaderSliver,
    @Deprecated('Use pinnedHeadersHeight') this.pinnedHeaderHeight = 0.0,
    this.pinnedHeaderSlivers,
    this.pinnedHeadersHeight = 0.0,
    this.scrollFractionNotifier,
    this.surfaceFillsViewport = false,
    this.controller,
    this.headerFadesOnScroll = false,
    this.showEdgeFade = false,
  })  : assert(
          pinnedHeaderSlivers == null || pinnedHeaderSliver == null,
          'Cannot use both pinnedHeaderSliver and pinnedHeaderSlivers',
        ),
        assert(
          (surfaceBody != null) != (surfaceSlivers != null),
          'Provide exactly one of surfaceBody or surfaceSlivers',
        );

  /// Content centered in the fixed-height parallax area.
  final Widget header;

  /// Content inside the white surface container.
  @Deprecated('Use surfaceSlivers')
  final Widget? surfaceBody;

  /// Slivers that form the surface content. Use [SliverList], [SliverGrid],
  /// etc. for lazy content. The surface decoration (background color, animated
  /// corner radius) is applied automatically.
  final List<Widget>? surfaceSlivers;

  /// Height of the transparent spacer revealing the header.
  final double headerHeight;

  /// Pull-to-refresh callback. When null, no [RefreshIndicator] is shown.
  final RefreshCallback? onRefresh;

  /// A sliver (e.g. [SliverPersistentHeader]) inserted before the spacer.
  @Deprecated('Use pinnedHeaderSlivers')
  final Widget? pinnedHeaderSliver;

  /// Height of the pinned header — offsets the parallax header downward.
  @Deprecated('Use pinnedHeadersHeight')
  final double pinnedHeaderHeight;

  /// Slivers inserted before the transparent spacer, creating pinned bars that
  /// stay visible while content scrolls.
  final List<Widget>? pinnedHeaderSlivers;

  /// Combined height of all pinned header slivers — offsets the parallax
  /// header downward so it doesn't overlap.
  final double pinnedHeadersHeight;

  /// Externally-provided notifier. When set, the layout writes scroll fraction
  /// to it. When null, an internal notifier is used.
  final ValueNotifier<double>? scrollFractionNotifier;

  /// Optional scroll controller for the internal [CustomScrollView].
  final ScrollController? controller;

  /// When true, the header fades out as the user scrolls.
  final bool headerFadesOnScroll;

  /// When true, a gradient overlay fades in at the surface junction as the
  /// user scrolls, providing a soft edge affordance.
  final bool showEdgeFade;

  // ignore: deprecated_member_use_from_same_package
  /// When true the [surfaceBody] is constrained to the initially-visible
  /// portion of the surface so that centering widgets like [Center] appear in
  /// the visible area, not in the middle of the full viewport-tall container.
  ///
  /// The surface background always stretches to at least viewport height
  /// regardless of this flag — this flag only controls the body constraint.
  final bool surfaceFillsViewport;

  @override
  State<ParallaxSurfaceLayout> createState() => _ParallaxSurfaceLayoutState();
}

class _ParallaxSurfaceLayoutState extends State<ParallaxSurfaceLayout> {
  final _internalNotifier = ValueNotifier<double>(0.0);

  ValueNotifier<double> get _effectiveNotifier =>
      widget.scrollFractionNotifier ?? _internalNotifier;

  // ignore: deprecated_member_use_from_same_package
  List<Widget> get _effectivePinned =>
      widget.pinnedHeaderSlivers ??
      // ignore: deprecated_member_use_from_same_package
      [if (widget.pinnedHeaderSliver != null) widget.pinnedHeaderSliver!];

  double get _effectivePinnedHeight => widget.pinnedHeaderSlivers != null
      ? widget.pinnedHeadersHeight
      // ignore: deprecated_member_use_from_same_package
      : widget.pinnedHeaderHeight;

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
              Widget result = Transform.translate(
                offset: Offset(0, -sf * widget.headerHeight * kParallaxRatio),
                child: child,
              );
              if (widget.headerFadesOnScroll) {
                result = Opacity(
                  opacity: (1 - sf).clamp(0.0, 1.0),
                  child: result,
                );
              }
              return result;
            },
            child: Padding(
              padding: EdgeInsets.only(top: _effectivePinnedHeight),
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

          // Layer 3: Edge fade (optional)
          if (widget.showEdgeFade)
            Positioned(
              top: _effectivePinnedHeight + widget.headerHeight,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _effectiveNotifier,
                  builder: (context, sf, child) => Opacity(
                    opacity: sf.clamp(0.0, 1.0),
                    child: child,
                  ),
                  child: Container(
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surfaceContainerLowest,
                          theme.colorScheme.surfaceContainerLowest
                              .withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollView(ThemeData theme) {
    final scrollView = CustomScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Pinned headers (if provided)
        ..._effectivePinned,

        // Transparent spacer — reveals header behind
        SliverToBoxAdapter(
          child: SizedBox(height: widget.headerHeight),
        ),

        // Surface container with animated corner radius
        if (widget.surfaceSlivers != null)
          ..._buildSurfaceSlivers(theme)
        else
          // ignore: deprecated_member_use_from_same_package
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

  /// Deprecated box-based surface path.
  Widget _buildSurfaceSliver(ThemeData theme) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.viewportMainAxisExtent;
        // ignore: deprecated_member_use_from_same_package
        final surfaceBody = widget.surfaceBody!;
        final body = widget.surfaceFillsViewport
            ? Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: viewportHeight -
                      widget.headerHeight -
                      _effectivePinnedHeight,
                  child: surfaceBody,
                ),
              )
            : surfaceBody;

        return SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewportHeight),
            child: _buildDecoratedSurface(theme, body),
          ),
        );
      },
    );
  }

  /// Sliver-based surface path — returns a list of slivers to spread into
  /// the CustomScrollView.
  List<Widget> _buildSurfaceSlivers(ThemeData theme) {
    final surfaceColor = theme.colorScheme.surfaceContainerLowest;
    return [
      ValueListenableBuilder<double>(
        valueListenable: _effectiveNotifier,
        builder: (context, sf, child) {
          final radius = kSurfaceCornerRadius * (1.0 - sf);
          return _SliverDecoratedBox(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: radius > 0
                  ? BorderRadius.vertical(top: Radius.circular(radius))
                  : null,
            ),
            child: child!,
          );
        },
        child: SliverMainAxisGroup(
          slivers: [
            ...widget.surfaceSlivers!,
            SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(color: surfaceColor),
            ),
          ],
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// StatusBarOverlay — Stack-based status-bar coverage for surfaceBody screens.
// ---------------------------------------------------------------------------

/// Wraps [child] in a [Stack] with a status-bar-height overlay that lerps
/// from [ColorScheme.surface] to [ColorScheme.surfaceContainerLowest].
///
/// Use this for screens that need safe-area color coverage without inserting a
/// pinned sliver inside [ParallaxSurfaceLayout] (which can conflict with the
/// deprecated [ParallaxSurfaceLayout.surfaceBody] code path).
class StatusBarOverlay extends StatelessWidget {
  const StatusBarOverlay({
    super.key,
    required this.scrollFractionNotifier,
    required this.child,
  });

  final ValueNotifier<double> scrollFractionNotifier;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: scrollFractionNotifier,
              builder: (_, sf, __) => SizedBox(
                height: safeTop,
                child: ColoredBox(
                  color: Color.lerp(
                    colors.surface,
                    colors.surfaceContainerLowest,
                    sf,
                  )!,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SafeAreaPinnedDelegate — minimal pinned header for status-bar coverage.
// ---------------------------------------------------------------------------

/// A [SliverPersistentHeaderDelegate] that paints an opaque background over the
/// status-bar area, lerping from [ColorScheme.surface] (at rest) to
/// [ColorScheme.surfaceContainerLowest] (when scrolled).
///
/// Use this for screens that need safe-area pinning without a functional bar
/// (e.g. no address bar, no search field).
class SafeAreaPinnedDelegate extends SliverPersistentHeaderDelegate {
  SafeAreaPinnedDelegate({
    required this.topPadding,
    required this.scrollFractionNotifier,
  });

  final double topPadding;
  final ValueNotifier<double> scrollFractionNotifier;

  @override
  double get maxExtent => topPadding;
  @override
  double get minExtent => topPadding;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: scrollFractionNotifier,
      builder: (context, sf, _) => ColoredBox(
        color: Color.lerp(
          colors.surface,
          colors.surfaceContainerLowest,
          sf,
        )!,
      ),
    );
  }

  @override
  bool shouldRebuild(SafeAreaPinnedDelegate old) =>
      old.topPadding != topPadding;
}

// ---------------------------------------------------------------------------
// Private render object: paints a BoxDecoration behind a sliver child.
// ---------------------------------------------------------------------------

class _SliverDecoratedBox extends SingleChildRenderObjectWidget {
  const _SliverDecoratedBox({
    required this.decoration,
    required Widget super.child,
  });

  final BoxDecoration decoration;

  @override
  _RenderSliverDecoratedBox createRenderObject(BuildContext context) {
    return _RenderSliverDecoratedBox(decoration: decoration);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverDecoratedBox renderObject,
  ) {
    renderObject.decoration = decoration;
  }
}

class _RenderSliverDecoratedBox extends RenderProxySliver {
  _RenderSliverDecoratedBox({required BoxDecoration decoration})
      : _decoration = decoration;

  BoxDecoration _decoration;
  BoxPainter? _painter;

  set decoration(BoxDecoration value) {
    if (_decoration == value) return;
    _painter?.dispose();
    _painter = null;
    _decoration = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (geometry == null || !geometry!.visible) return;
    _painter ??= _decoration.createBoxPainter(markNeedsPaint);
    final size = switch (constraints.axis) {
      Axis.vertical => Size(constraints.crossAxisExtent, geometry!.paintExtent),
      Axis.horizontal =>
        Size(geometry!.paintExtent, constraints.crossAxisExtent),
    };
    _painter!.paint(context.canvas, offset, ImageConfiguration(size: size));
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _painter?.dispose();
    super.dispose();
  }
}
