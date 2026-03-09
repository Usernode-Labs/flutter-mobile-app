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

/// Padding added by standard pinned bars beyond the safe-area inset
/// (space8 + barContent + space8 = 8 + 32 + 8). The auto-injected sliver
/// includes this so screens without bars align with screens that have them.
const kPinnedBarPadding = 48.0;

/// Vertical inset from the surface top edge to the first content sliver.
/// Tuned for 48px content slots: 8px gap + 48px widget places title text
/// at ~22px from the surface edge, matching Challenges' prior art
/// (`_kTopInset=8 + kTabBarHeight=48`).
const kSurfaceTopInset = 8.0;

/// A layout that places a fixed [header] behind a scrolling surface container.
///
/// As the user scrolls, the header translates upward at [kParallaxRatio] of the
/// scroll speed, while the surface container's top corners animate from
/// [kSurfaceCornerRadius] to zero.
///
/// Provide exactly one of [surfaceSlivers], [nestedBody], or the deprecated
/// [surfaceBody]:
/// - [surfaceSlivers] for lazy sliver-based content in a [CustomScrollView].
/// - [nestedBody] for screens that need [NestedScrollView] (e.g. TabBarView).
///
/// Use [pinnedHeaderSlivers] for one or more pinned bars above the content.
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
    this.nestedBody,
    this.headerHeight = kDefaultHeaderHeight,
    this.onRefresh,
    this.onRefreshStatusChange,
    this.refreshNotificationPredicate,
    @Deprecated('Use pinnedHeaderSlivers') this.pinnedHeaderSliver,
    @Deprecated('Use pinnedHeadersHeight') this.pinnedHeaderHeight = 0.0,
    this.pinnedHeaderSlivers,
    this.pinnedHeadersHeight = 0.0,
    this.surfacePinnedSlivers,
    this.surfacePinnedHeight = 0.0,
    this.scrollFractionNotifier,
    this.surfaceFillsViewport = false,
    this.controller,
    this.headerFadesOnScroll = false,
    this.showEdgeFade = false,
    this.safeAreaOverlay = true,
    this.headerOverlay,
  })  : assert(
          pinnedHeaderSlivers == null || pinnedHeaderSliver == null,
          'Cannot use both pinnedHeaderSliver and pinnedHeaderSlivers',
        ),
        assert(
          // Exactly one of the three content params must be non-null.
          // ignore: deprecated_member_use_from_same_package
          (surfaceBody != null ||
                  surfaceSlivers != null ||
                  nestedBody != null) &&
              // ignore: deprecated_member_use_from_same_package
              !(surfaceBody != null && surfaceSlivers != null) &&
              // ignore: deprecated_member_use_from_same_package
              !(surfaceBody != null && nestedBody != null) &&
              !(surfaceSlivers != null && nestedBody != null),
          'Provide exactly one of surfaceBody, surfaceSlivers, or nestedBody',
        ),
        assert(
          surfacePinnedSlivers == null || nestedBody != null,
          'surfacePinnedSlivers is only valid with nestedBody',
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

  /// Body widget for a [NestedScrollView]. When set, PSL uses
  /// [NestedScrollView] internally instead of [CustomScrollView].
  ///
  /// Use this for screens with independently-scrollable tab content
  /// (e.g. [TabBarView]).
  final Widget? nestedBody;

  /// Height of the transparent spacer revealing the header.
  final double headerHeight;

  /// Pull-to-refresh callback. When null, no [RefreshIndicator] is shown.
  final RefreshCallback? onRefresh;

  /// When set alongside [onRefresh], uses [RefreshIndicator.noSpinner] and
  /// reports status changes through this callback. Useful for driving custom
  /// pull-to-refresh animations (e.g. scale effects on the header).
  final ValueChanged<RefreshIndicatorStatus?>? onRefreshStatusChange;

  /// Custom predicate for [RefreshIndicator]. When null, uses the default.
  final ScrollNotificationPredicate? refreshNotificationPredicate;

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

  /// Slivers pinned after the spacer, at the surface junction. Only valid
  /// with [nestedBody]. Use for elements like a tab bar that should pin at
  /// the surface boundary with animated corner radius.
  final List<Widget>? surfacePinnedSlivers;

  /// Combined height of [surfacePinnedSlivers].
  final double surfacePinnedHeight;

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

  /// When true and no [pinnedHeaderSlivers] are provided, the layout injects
  /// an internal pinned [SafeAreaPinnedDelegate] that offsets the surface
  /// downward by the status-bar height plus [kPinnedBarPadding] and lerps
  /// from transparent to [ColorScheme.surfaceContainerLowest] as the user
  /// scrolls.
  ///
  /// The extra [kPinnedBarPadding] (48px) matches the space that standard
  /// pinned-bar delegates add beyond the safe-area inset, keeping all
  /// screens' surfaces at the same Y position.
  ///
  /// Screens with [pinnedHeaderSlivers] handle safe-area internally through
  /// their delegates, so the auto-sliver is skipped. When adding pinned
  /// headers to a screen, ensure the first delegate includes
  /// `MediaQuery.of(context).padding.top + kPinnedBarPadding` in its
  /// extent — otherwise the surface will sit higher than other screens.
  final bool safeAreaOverlay;

  // ignore: deprecated_member_use_from_same_package
  /// When true the [surfaceBody] is constrained to the initially-visible
  /// portion of the surface so that centering widgets like [Center] appear in
  /// the visible area, not in the middle of the full viewport-tall container.
  ///
  /// The surface background always stretches to at least viewport height
  /// regardless of this flag — this flag only controls the body constraint.
  final bool surfaceFillsViewport;

  /// Interactive widget rendered ABOVE the scroll surface in PSL's Stack,
  /// parallaxing and fading with the header. For CTA buttons that visually
  /// belong to the header but need tap access.
  ///
  /// Non-interactive areas use [HitTestBehavior.deferToChild] so scroll
  /// gestures pass through; only explicit [GestureDetector]s consume taps.
  final Widget? headerOverlay;

  @override
  State<ParallaxSurfaceLayout> createState() => _ParallaxSurfaceLayoutState();
}

class _ParallaxSurfaceLayoutState extends State<ParallaxSurfaceLayout> {
  final _internalNotifier = ValueNotifier<double>(0.0);
  double _autoSliverExtent = 0.0;

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
    // Matches the structural offset that pinned-header screens get for free.
    // Used in: header padding, edge fade position, deprecated surfaceFillsViewport.
    _autoSliverExtent = (widget.safeAreaOverlay && _effectivePinned.isEmpty)
        ? MediaQuery.of(context).padding.top + kPinnedBarPadding
        : 0.0;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Layer 1: Header (parallax)
          _buildHeaderLayer(),

          // Layer 2: Scrolling content surface
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: _buildScrollView(theme),
          ),

          // Layer 3: Header overlay (interactive, parallaxes with header)
          if (widget.headerOverlay != null) _buildHeaderOverlayLayer(),

          // Layer 4: Edge fade (optional)
          if (widget.showEdgeFade)
            Positioned(
              top: _effectivePinnedHeight +
                  widget.headerHeight +
                  _autoSliverExtent,
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

  // ---------------------------------------------------------------------------
  // Layer builders
  // ---------------------------------------------------------------------------

  /// Wraps [child] in a parallax transform + optional fade driven by scroll
  /// fraction. Shared by header and header-overlay layers.
  Widget _buildParallaxLayer(Widget child) {
    return ValueListenableBuilder<double>(
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
        padding:
            EdgeInsets.only(top: _effectivePinnedHeight + _autoSliverExtent),
        child: child,
      ),
    );
  }

  Widget _buildHeaderLayer() {
    return _buildParallaxLayer(
      SizedOverflowBox(
        size: Size(double.infinity, widget.headerHeight),
        alignment: Alignment.center,
        child: widget.header,
      ),
    );
  }

  /// Layer 3: headerOverlay — positioned and parallaxed identically to the
  /// header, but rendered above the scroll surface so taps land naturally.
  /// Uses [HitTestBehavior.deferToChild] so scroll gestures pass through
  /// non-interactive areas.
  ///
  /// Hit-test gating: once the surface scrolls over the overlay (`sf > 0`),
  /// [IgnorePointer] disables hit-testing so surface content receives taps.
  Widget _buildHeaderOverlayLayer() {
    return ValueListenableBuilder<double>(
      valueListenable: _effectiveNotifier,
      builder: (context, sf, child) => IgnorePointer(
        ignoring: sf > 0.0,
        child: child,
      ),
      child: _buildParallaxLayer(
        SizedBox(
          height: widget.headerHeight,
          child: widget.headerOverlay,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scroll view dispatch
  // ---------------------------------------------------------------------------

  Widget _buildScrollView(ThemeData theme) {
    final scrollView = widget.nestedBody != null
        ? _buildNestedScrollView(theme)
        : _buildCustomScrollView(theme);

    return _wrapWithRefreshIndicator(scrollView);
  }

  Widget _wrapWithRefreshIndicator(Widget scrollView) {
    if (widget.onRefresh == null) return scrollView;

    if (widget.onRefreshStatusChange != null) {
      return RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh!,
        onStatusChange: widget.onRefreshStatusChange,
        notificationPredicate: widget.refreshNotificationPredicate ??
            defaultScrollNotificationPredicate,
        child: scrollView,
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh!,
      notificationPredicate: widget.refreshNotificationPredicate ??
          defaultScrollNotificationPredicate,
      child: scrollView,
    );
  }

  // ---------------------------------------------------------------------------
  // CustomScrollView path (surfaceSlivers / surfaceBody)
  // ---------------------------------------------------------------------------

  /// Shared prefix slivers: pinned headers + auto safe-area bar + spacer.
  List<Widget> _commonHeaderSlivers() {
    return [
      ..._effectivePinned,

      // When no user-provided pinned headers exist, inject a pinned safe-area
      // bar so the surface starts at the same Y as screens with pinned headers
      // (safeTop + headerHeight). This keeps scroll fraction based on
      // headerHeight alone, making parallax rate consistent across all screens.
      if (_autoSliverExtent > 0)
        SliverPersistentHeader(
          pinned: true,
          delegate: SafeAreaPinnedDelegate(
            topPadding: _autoSliverExtent,
            scrollFractionNotifier: _effectiveNotifier,
          ),
        ),

      // Transparent spacer — reveals header behind
      SliverToBoxAdapter(
        child: SizedBox(height: widget.headerHeight),
      ),
    ];
  }

  Widget _buildCustomScrollView(ThemeData theme) {
    return CustomScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ..._commonHeaderSlivers(),

        // Surface container with animated corner radius
        if (widget.surfaceSlivers != null)
          ..._buildSurfaceSlivers(theme)
        else
          // ignore: deprecated_member_use_from_same_package
          _buildSurfaceSliver(theme),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // NestedScrollView path (nestedBody)
  // ---------------------------------------------------------------------------

  Widget _buildNestedScrollView(ThemeData theme) {
    final surfaceColor = theme.colorScheme.surfaceContainerLowest;

    return NestedScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(),
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          ..._commonHeaderSlivers(),

          // Surface-pinned slivers (e.g. tab bar with corner radius)
          if (widget.surfacePinnedSlivers != null)
            ...widget.surfacePinnedSlivers!,
        ];
      },
      body: ColoredBox(
        color: surfaceColor,
        child: widget.nestedBody!,
      ),
    );
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
    // ignore: deprecated_member_use_from_same_package
    assert(() {
      // ignore: deprecated_member_use_from_same_package
      if (!widget.surfaceFillsViewport && widget.surfaceBody != null) {
        // ignore: deprecated_member_use_from_same_package
        _debugCheckUnboundedFlexChild(widget.surfaceBody!);
      }
      return true;
    }());

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
                      _effectivePinnedHeight -
                      _autoSliverExtent,
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
            const SliverToBoxAdapter(
              child: SizedBox(height: kSurfaceTopInset),
            ),
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
// Debug helper: detect Expanded/Flexible in surfaceBody
// ---------------------------------------------------------------------------

/// Walks the widget tree looking for [Expanded] or [Flexible] as a direct
/// child of a vertical [Flex] (Column). This combination crashes with
/// unbounded height inside `SliverToBoxAdapter → ConstrainedBox`.
///
/// Only runs in debug mode via assert().
void _debugCheckUnboundedFlexChild(Widget widget) {
  if (widget is Flex && widget.direction == Axis.vertical) {
    for (final child in widget.children) {
      if (child is Flexible) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: FlutterError.fromParts([
            ErrorSummary(
              'ParallaxSurfaceLayout.surfaceBody contains a vertical '
              'Flex with Expanded/Flexible children.',
            ),
            ErrorDescription(
              'The deprecated surfaceBody path wraps content in '
              'SliverToBoxAdapter → ConstrainedBox which provides '
              'unbounded maxHeight. Expanded/Flexible children will '
              'crash with "RenderFlex children have non-zero flex but '
              'incoming height constraints are unbounded".\n\n'
              'Fix: migrate to surfaceSlivers and use '
              'SliverFillRemaining for centering.',
            ),
          ]),
        ));
        return;
      }
    }
  }

  // Recurse into known single-child wrappers.
  if (widget is ProxyWidget) {
    _debugCheckUnboundedFlexChild(widget.child);
  } else if (widget is SingleChildRenderObjectWidget && widget.child != null) {
    _debugCheckUnboundedFlexChild(widget.child!);
  }
}

// ---------------------------------------------------------------------------
// StatusBarOverlay — Stack-based status-bar coverage for surfaceBody screens.
// ---------------------------------------------------------------------------

/// Wraps [child] in a [Stack] with a status-bar-height overlay that lerps
/// from transparent to [ColorScheme.surfaceContainerLowest].
///
/// Use this for screens that need safe-area color coverage without inserting a
/// pinned sliver inside [ParallaxSurfaceLayout] (which can conflict with the
/// deprecated [ParallaxSurfaceLayout.surfaceBody] code path).
@Deprecated(
  'ParallaxSurfaceLayout handles safe-area overlay automatically '
  'via the safeAreaOverlay param. '
  'This class will be removed in a future release.',
)
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
                    Colors.transparent,
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

/// A [SliverPersistentHeaderDelegate] that paints a background over the
/// status-bar area, lerping from transparent (at rest) to
/// [ColorScheme.surfaceContainerLowest] (when scrolled).
///
/// Use this for screens that need safe-area pinning without a functional bar
/// (e.g. no address bar, no search field).
///
/// **Invariant:** [minExtent] and [maxExtent] must both equal [topPadding],
/// which should be `MediaQuery.of(context).padding.top + kPinnedBarPadding`
/// for screens without custom pinned bars. Changing them will shift the
/// surface Y position and break cross-screen alignment.
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
      builder: (context, sf, _) => SizedBox.expand(
        child: ColoredBox(
          color: Color.lerp(
            Colors.transparent,
            colors.surfaceContainerLowest,
            sf,
          )!,
        ),
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
