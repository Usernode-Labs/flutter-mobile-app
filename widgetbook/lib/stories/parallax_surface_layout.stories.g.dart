// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'parallax_surface_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs>;
typedef _Scenario = ParallaxSurfaceLayoutScenario;
typedef _Defaults = ParallaxSurfaceLayoutDefaults;
typedef _Story = ParallaxSurfaceLayoutStory;
typedef _Args = ParallaxSurfaceLayoutArgs;
final ParallaxSurfaceLayoutComponent =
    Component<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs>(
      name: meta.name ?? 'ParallaxSurfaceLayout',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A layout that places a fixed [header] behind a scrolling surface container.

As the user scrolls, the header translates upward at [kParallaxRatio] of the
scroll speed, while the surface container's top corners animate from
[kSurfaceCornerRadius] to zero.

Provide exactly one of [surfaceSlivers], [nestedBody], or the deprecated
[surfaceBody]:
- [surfaceSlivers] for lazy sliver-based content in a [CustomScrollView].
- [nestedBody] for screens that need [NestedScrollView] (e.g. TabBarView).

Use [pinnedHeaderSlivers] for one or more pinned bars above the content.

When [scrollFractionNotifier] is provided the layout writes the scroll
fraction (0.0 – 1.0) to that notifier so external delegates can react to
scroll position.  When null, an internal notifier is used.''',
      stories: [
        $Default..$generatedName = 'Default',
        $WithTitle..$generatedName = 'WithTitle',
      ],
    );
typedef ParallaxSurfaceLayoutScenario =
    Scenario<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs>;
typedef ParallaxSurfaceLayoutDefaults =
    Defaults<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs>;

class ParallaxSurfaceLayoutStory
    extends Story<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs> {
  ParallaxSurfaceLayoutStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ParallaxSurfaceLayout, ParallaxSurfaceLayoutArgs>?
    builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => ParallaxSurfaceLayout(
               key: args.key,
               header: args.header,
               surfaceBody: args.surfaceBody,
               surfaceSlivers: args.surfaceSlivers,
               nestedBody: args.nestedBody,
               headerHeight: args.headerHeight,
               onRefresh: args.onRefresh,
               onRefreshStatusChange: args.onRefreshStatusChange,
               refreshNotificationPredicate: args.refreshNotificationPredicate,
               pinnedHeaderSliver: args.pinnedHeaderSliver,
               pinnedHeaderHeight: args.pinnedHeaderHeight,
               pinnedHeaderSlivers: args.pinnedHeaderSlivers,
               pinnedHeadersHeight: args.pinnedHeadersHeight,
               surfacePinnedSlivers: args.surfacePinnedSlivers,
               surfacePinnedHeight: args.surfacePinnedHeight,
               scrollFractionNotifier: args.scrollFractionNotifier,
               surfaceFillsViewport: args.surfaceFillsViewport,
               controller: args.controller,
               headerFadesOnScroll: args.headerFadesOnScroll,
               showEdgeFade: args.showEdgeFade,
               safeAreaOverlay: args.safeAreaOverlay,
               headerOverlay: args.headerOverlay,
               title: args.title,
             ),
       );
}

class ParallaxSurfaceLayoutArgs extends StoryArgs<ParallaxSurfaceLayout> {
  ParallaxSurfaceLayoutArgs({
    Arg<Key?>? key,
    required Arg<Widget> header,
    Arg<Widget?>? surfaceBody,
    Arg<List<Widget>?>? surfaceSlivers,
    Arg<Widget?>? nestedBody,
    Arg<double>? headerHeight,
    Arg<Future<void> Function()?>? onRefresh,
    Arg<void Function(RefreshIndicatorStatus?)?>? onRefreshStatusChange,
    Arg<bool Function(ScrollNotification)?>? refreshNotificationPredicate,
    Arg<Widget?>? pinnedHeaderSliver,
    Arg<double>? pinnedHeaderHeight,
    Arg<List<Widget>?>? pinnedHeaderSlivers,
    Arg<double>? pinnedHeadersHeight,
    Arg<List<Widget>?>? surfacePinnedSlivers,
    Arg<double>? surfacePinnedHeight,
    Arg<ValueNotifier<double>?>? scrollFractionNotifier,
    Arg<bool>? surfaceFillsViewport,
    Arg<ScrollController?>? controller,
    Arg<bool>? headerFadesOnScroll,
    Arg<bool>? showEdgeFade,
    Arg<bool>? safeAreaOverlay,
    Arg<Widget?>? headerOverlay,
    Arg<String?>? title,
  }) : this.keyArg = $initArg('key', key, null),
       this.headerArg = $initArg('header', header, null)!,
       this.surfaceBodyArg = $initArg('surfaceBody', surfaceBody, null),
       this.surfaceSliversArg = $initArg(
         'surfaceSlivers',
         surfaceSlivers,
         null,
       ),
       this.nestedBodyArg = $initArg('nestedBody', nestedBody, null),
       this.headerHeightArg = $initArg(
         'headerHeight',
         headerHeight,
         DoubleArg(kDefaultHeaderHeight),
       )!,
       this.onRefreshArg = $initArg('onRefresh', onRefresh, null),
       this.onRefreshStatusChangeArg = $initArg(
         'onRefreshStatusChange',
         onRefreshStatusChange,
         null,
       ),
       this.refreshNotificationPredicateArg = $initArg(
         'refreshNotificationPredicate',
         refreshNotificationPredicate,
         null,
       ),
       this.pinnedHeaderSliverArg = $initArg(
         'pinnedHeaderSliver',
         pinnedHeaderSliver,
         null,
       ),
       this.pinnedHeaderHeightArg = $initArg(
         'pinnedHeaderHeight',
         pinnedHeaderHeight,
         DoubleArg(0.0),
       )!,
       this.pinnedHeaderSliversArg = $initArg(
         'pinnedHeaderSlivers',
         pinnedHeaderSlivers,
         null,
       ),
       this.pinnedHeadersHeightArg = $initArg(
         'pinnedHeadersHeight',
         pinnedHeadersHeight,
         DoubleArg(0.0),
       )!,
       this.surfacePinnedSliversArg = $initArg(
         'surfacePinnedSlivers',
         surfacePinnedSlivers,
         null,
       ),
       this.surfacePinnedHeightArg = $initArg(
         'surfacePinnedHeight',
         surfacePinnedHeight,
         DoubleArg(0.0),
       )!,
       this.scrollFractionNotifierArg = $initArg(
         'scrollFractionNotifier',
         scrollFractionNotifier,
         null,
       ),
       this.surfaceFillsViewportArg = $initArg(
         'surfaceFillsViewport',
         surfaceFillsViewport,
         BoolArg(false),
       )!,
       this.controllerArg = $initArg('controller', controller, null),
       this.headerFadesOnScrollArg = $initArg(
         'headerFadesOnScroll',
         headerFadesOnScroll,
         BoolArg(true),
       )!,
       this.showEdgeFadeArg = $initArg(
         'showEdgeFade',
         showEdgeFade,
         BoolArg(false),
       )!,
       this.safeAreaOverlayArg = $initArg(
         'safeAreaOverlay',
         safeAreaOverlay,
         BoolArg(true),
       )!,
       this.headerOverlayArg = $initArg('headerOverlay', headerOverlay, null),
       this.titleArg = $initArg('title', title, NullableStringArg(null))!;

  ParallaxSurfaceLayoutArgs.fixed({
    Key? key,
    required Widget header,
    Widget? surfaceBody,
    List<Widget>? surfaceSlivers,
    Widget? nestedBody,
    double headerHeight = kDefaultHeaderHeight,
    Future<void> Function()? onRefresh,
    void Function(RefreshIndicatorStatus?)? onRefreshStatusChange,
    bool Function(ScrollNotification)? refreshNotificationPredicate,
    Widget? pinnedHeaderSliver,
    double pinnedHeaderHeight = 0.0,
    List<Widget>? pinnedHeaderSlivers,
    double pinnedHeadersHeight = 0.0,
    List<Widget>? surfacePinnedSlivers,
    double surfacePinnedHeight = 0.0,
    ValueNotifier<double>? scrollFractionNotifier,
    bool surfaceFillsViewport = false,
    ScrollController? controller,
    bool headerFadesOnScroll = true,
    bool showEdgeFade = false,
    bool safeAreaOverlay = true,
    Widget? headerOverlay,
    String? title = null,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.headerArg = Arg.fixed(header),
       this.surfaceBodyArg = surfaceBody == null
           ? null
           : Arg.fixed(surfaceBody),
       this.surfaceSliversArg = surfaceSlivers == null
           ? null
           : Arg.fixed(surfaceSlivers),
       this.nestedBodyArg = nestedBody == null ? null : Arg.fixed(nestedBody),
       this.headerHeightArg = Arg.fixed(headerHeight),
       this.onRefreshArg = onRefresh == null ? null : Arg.fixed(onRefresh),
       this.onRefreshStatusChangeArg = onRefreshStatusChange == null
           ? null
           : Arg.fixed(onRefreshStatusChange),
       this.refreshNotificationPredicateArg =
           refreshNotificationPredicate == null
           ? null
           : Arg.fixed(refreshNotificationPredicate),
       this.pinnedHeaderSliverArg = pinnedHeaderSliver == null
           ? null
           : Arg.fixed(pinnedHeaderSliver),
       this.pinnedHeaderHeightArg = Arg.fixed(pinnedHeaderHeight),
       this.pinnedHeaderSliversArg = pinnedHeaderSlivers == null
           ? null
           : Arg.fixed(pinnedHeaderSlivers),
       this.pinnedHeadersHeightArg = Arg.fixed(pinnedHeadersHeight),
       this.surfacePinnedSliversArg = surfacePinnedSlivers == null
           ? null
           : Arg.fixed(surfacePinnedSlivers),
       this.surfacePinnedHeightArg = Arg.fixed(surfacePinnedHeight),
       this.scrollFractionNotifierArg = scrollFractionNotifier == null
           ? null
           : Arg.fixed(scrollFractionNotifier),
       this.surfaceFillsViewportArg = Arg.fixed(surfaceFillsViewport),
       this.controllerArg = controller == null ? null : Arg.fixed(controller),
       this.headerFadesOnScrollArg = Arg.fixed(headerFadesOnScroll),
       this.showEdgeFadeArg = Arg.fixed(showEdgeFade),
       this.safeAreaOverlayArg = Arg.fixed(safeAreaOverlay),
       this.headerOverlayArg = headerOverlay == null
           ? null
           : Arg.fixed(headerOverlay),
       this.titleArg = title == null ? null : Arg.fixed(title);

  final Arg<Key?>? keyArg;

  final Arg<Widget> headerArg;

  final Arg<Widget?>? surfaceBodyArg;

  final Arg<List<Widget>?>? surfaceSliversArg;

  final Arg<Widget?>? nestedBodyArg;

  final Arg<double> headerHeightArg;

  final Arg<Future<void> Function()?>? onRefreshArg;

  final Arg<void Function(RefreshIndicatorStatus?)?>? onRefreshStatusChangeArg;

  final Arg<bool Function(ScrollNotification)?>?
  refreshNotificationPredicateArg;

  final Arg<Widget?>? pinnedHeaderSliverArg;

  final Arg<double> pinnedHeaderHeightArg;

  final Arg<List<Widget>?>? pinnedHeaderSliversArg;

  final Arg<double> pinnedHeadersHeightArg;

  final Arg<List<Widget>?>? surfacePinnedSliversArg;

  final Arg<double> surfacePinnedHeightArg;

  final Arg<ValueNotifier<double>?>? scrollFractionNotifierArg;

  final Arg<bool> surfaceFillsViewportArg;

  final Arg<ScrollController?>? controllerArg;

  final Arg<bool> headerFadesOnScrollArg;

  final Arg<bool> showEdgeFadeArg;

  final Arg<bool> safeAreaOverlayArg;

  final Arg<Widget?>? headerOverlayArg;

  final Arg<String?>? titleArg;

  Key? get key => keyArg?.value;

  Widget get header => headerArg.value;

  Widget? get surfaceBody => surfaceBodyArg?.value;

  List<Widget>? get surfaceSlivers => surfaceSliversArg?.value;

  Widget? get nestedBody => nestedBodyArg?.value;

  double get headerHeight => headerHeightArg.value;

  Future<void> Function()? get onRefresh => onRefreshArg?.value;

  void Function(RefreshIndicatorStatus?)? get onRefreshStatusChange =>
      onRefreshStatusChangeArg?.value;

  bool Function(ScrollNotification)? get refreshNotificationPredicate =>
      refreshNotificationPredicateArg?.value;

  Widget? get pinnedHeaderSliver => pinnedHeaderSliverArg?.value;

  double get pinnedHeaderHeight => pinnedHeaderHeightArg.value;

  List<Widget>? get pinnedHeaderSlivers => pinnedHeaderSliversArg?.value;

  double get pinnedHeadersHeight => pinnedHeadersHeightArg.value;

  List<Widget>? get surfacePinnedSlivers => surfacePinnedSliversArg?.value;

  double get surfacePinnedHeight => surfacePinnedHeightArg.value;

  ValueNotifier<double>? get scrollFractionNotifier =>
      scrollFractionNotifierArg?.value;

  bool get surfaceFillsViewport => surfaceFillsViewportArg.value;

  ScrollController? get controller => controllerArg?.value;

  bool get headerFadesOnScroll => headerFadesOnScrollArg.value;

  bool get showEdgeFade => showEdgeFadeArg.value;

  bool get safeAreaOverlay => safeAreaOverlayArg.value;

  Widget? get headerOverlay => headerOverlayArg?.value;

  String? get title => titleArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    headerArg,
    surfaceBodyArg,
    surfaceSliversArg,
    nestedBodyArg,
    headerHeightArg,
    onRefreshArg,
    onRefreshStatusChangeArg,
    refreshNotificationPredicateArg,
    pinnedHeaderSliverArg,
    pinnedHeaderHeightArg,
    pinnedHeaderSliversArg,
    pinnedHeadersHeightArg,
    surfacePinnedSliversArg,
    surfacePinnedHeightArg,
    scrollFractionNotifierArg,
    surfaceFillsViewportArg,
    controllerArg,
    headerFadesOnScrollArg,
    showEdgeFadeArg,
    safeAreaOverlayArg,
    headerOverlayArg,
    titleArg,
  ];
}
