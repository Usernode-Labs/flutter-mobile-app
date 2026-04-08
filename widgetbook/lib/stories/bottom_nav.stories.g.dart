// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'bottom_nav.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<BottomNav, BottomNavArgs>;
typedef _Scenario = BottomNavScenario;
typedef _Defaults = BottomNavDefaults;
typedef _Story = BottomNavStory;
typedef _Args = BottomNavArgs;
final BottomNavComponent = Component<BottomNav, BottomNavArgs>(
  name: meta.name ?? 'BottomNav',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A bottom navigation bar wrapping M3 [NavigationBar].

80dp height, 24px icons, labelMedium labels. Active state uses filled
icon (`fill: 1`) with [indicatorColor], inactive uses outlined icon
(`fill: 0`) with `outline` color.

Gains ripple, focus, keyboard navigation, and screen reader semantics
from the underlying M3 component. Visual appearance is controlled by
`navigationBarTheme` in [ColorIsExpensiveTheme].

Presentation-only — parent manages selection state via [selectedIndex]
and [onItemSelected] callback.''',
  stories: [$Default..$generatedName = 'Default'],
);
typedef BottomNavScenario = Scenario<BottomNav, BottomNavArgs>;
typedef BottomNavDefaults = Defaults<BottomNav, BottomNavArgs>;

class BottomNavStory extends Story<BottomNav, BottomNavArgs> {
  BottomNavStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<BottomNav, BottomNavArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => BottomNav(
               key: args.key,
               items: args.items,
               selectedIndex: args.selectedIndex,
               onItemSelected: args.onItemSelected,
               topBorder: args.topBorder,
             ),
       );
}

class BottomNavArgs extends StoryArgs<BottomNav> {
  BottomNavArgs({
    Arg<Key?>? key,
    required Arg<List<BottomNavItem>> items,
    Arg<int>? selectedIndex,
    Arg<void Function(int)?>? onItemSelected,
    Arg<bool>? topBorder,
  }) : this.keyArg = $initArg('key', key, null),
       this.itemsArg = $initArg('items', items, null)!,
       this.selectedIndexArg = $initArg(
         'selectedIndex',
         selectedIndex,
         IntArg(0),
       )!,
       this.onItemSelectedArg = $initArg(
         'onItemSelected',
         onItemSelected,
         null,
       ),
       this.topBorderArg = $initArg('topBorder', topBorder, BoolArg(true))!;

  BottomNavArgs.fixed({
    Key? key,
    required List<BottomNavItem> items,
    int selectedIndex = 0,
    void Function(int)? onItemSelected,
    bool topBorder = true,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.itemsArg = Arg.fixed(items),
       this.selectedIndexArg = Arg.fixed(selectedIndex),
       this.onItemSelectedArg = onItemSelected == null
           ? null
           : Arg.fixed(onItemSelected),
       this.topBorderArg = Arg.fixed(topBorder);

  final Arg<Key?>? keyArg;

  final Arg<List<BottomNavItem>> itemsArg;

  final Arg<int> selectedIndexArg;

  final Arg<void Function(int)?>? onItemSelectedArg;

  final Arg<bool> topBorderArg;

  Key? get key => keyArg?.value;

  List<BottomNavItem> get items => itemsArg.value;

  int get selectedIndex => selectedIndexArg.value;

  void Function(int)? get onItemSelected => onItemSelectedArg?.value;

  bool get topBorder => topBorderArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    itemsArg,
    selectedIndexArg,
    onItemSelectedArg,
    topBorderArg,
  ];
}
