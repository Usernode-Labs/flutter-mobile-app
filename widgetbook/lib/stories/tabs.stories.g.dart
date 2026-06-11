// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'tabs.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<Tabs, TabsArgs>;
typedef _Scenario = TabsScenario;
typedef _Defaults = TabsDefaults;
typedef _Story = TabsStory;
typedef _Args = TabsArgs;
final TabsComponent = Component<Tabs, TabsArgs>(
  name: meta.name ?? 'Tabs',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A tab view backed by M3 [TabBar] (primary style) + [TabBarView].

Combines a primary tab bar (labels, optional inline badges, underline
indicator, and divider) with a swipeable content area.

Two layout modes controlled by [isScrollable]:
- **Fixed** (default): equal-width tabs fill the bar.
- **Scrollable**: natural-width tabs in a horizontal scroll view.

Manages selection state internally and notifies the parent via
[onTabChanged].''',
  stories: [$Default..$generatedName = 'Default'],
);
typedef TabsScenario = Scenario<Tabs, TabsArgs>;
typedef TabsDefaults = Defaults<Tabs, TabsArgs>;

class TabsStory extends Story<Tabs, TabsArgs> {
  TabsStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<Tabs, TabsArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => Tabs(
                    key: args.key,
                    tabs: args.tabs,
                    children: args.children,
                    initialIndex: args.initialIndex,
                    onTabChanged: args.onTabChanged,
                    isScrollable: args.isScrollable,
                    showDivider: args.showDivider,
                  ),
        );
}

class TabsArgs extends StoryArgs<Tabs> {
  TabsArgs({
    Arg<Key?>? key,
    required Arg<List<TabItem>> tabs,
    required Arg<List<Widget>> children,
    Arg<int>? initialIndex,
    Arg<void Function(int)?>? onTabChanged,
    Arg<bool>? isScrollable,
    Arg<bool>? showDivider,
  })  : this.keyArg = $initArg('key', key, null),
        this.tabsArg = $initArg('tabs', tabs, null)!,
        this.childrenArg = $initArg('children', children, null)!,
        this.initialIndexArg = $initArg(
          'initialIndex',
          initialIndex,
          IntArg(0),
        )!,
        this.onTabChangedArg = $initArg('onTabChanged', onTabChanged, null),
        this.isScrollableArg = $initArg(
          'isScrollable',
          isScrollable,
          BoolArg(false),
        )!,
        this.showDividerArg = $initArg(
          'showDivider',
          showDivider,
          BoolArg(true),
        )!;

  TabsArgs.fixed({
    Key? key,
    required List<TabItem> tabs,
    required List<Widget> children,
    int initialIndex = 0,
    void Function(int)? onTabChanged,
    bool isScrollable = false,
    bool showDivider = true,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.tabsArg = Arg.fixed(tabs),
        this.childrenArg = Arg.fixed(children),
        this.initialIndexArg = Arg.fixed(initialIndex),
        this.onTabChangedArg =
            onTabChanged == null ? null : Arg.fixed(onTabChanged),
        this.isScrollableArg = Arg.fixed(isScrollable),
        this.showDividerArg = Arg.fixed(showDivider);

  final Arg<Key?>? keyArg;

  final Arg<List<TabItem>> tabsArg;

  final Arg<List<Widget>> childrenArg;

  final Arg<int> initialIndexArg;

  final Arg<void Function(int)?>? onTabChangedArg;

  final Arg<bool> isScrollableArg;

  final Arg<bool> showDividerArg;

  Key? get key => keyArg?.value;

  List<TabItem> get tabs => tabsArg.value;

  List<Widget> get children => childrenArg.value;

  int get initialIndex => initialIndexArg.value;

  void Function(int)? get onTabChanged => onTabChangedArg?.value;

  bool get isScrollable => isScrollableArg.value;

  bool get showDivider => showDividerArg.value;

  @override
  List<Arg?> get list => [
        keyArg,
        tabsArg,
        childrenArg,
        initialIndexArg,
        onTabChangedArg,
        isScrollableArg,
        showDividerArg,
      ];
}
