// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_category_tile.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ChallengeCategoryTile, ChallengeCategoryTileArgs>;
typedef _Scenario = ChallengeCategoryTileScenario;
typedef _Defaults = ChallengeCategoryTileDefaults;
typedef _Story = ChallengeCategoryTileStory;
typedef _Args = ChallengeCategoryTileArgs;
final ChallengeCategoryTileComponent =
    Component<ChallengeCategoryTile, ChallengeCategoryTileArgs>(
      name: meta.name ?? 'ChallengeCategoryTile',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''An expandable list tile that groups sub-challenges by category.

Shows a category icon, name, remaining/completed counts, and total points.
Expands to reveal individual challenge chips styled as completed (disabled)
or remaining (active tonal).

Built on M3 [ExpansionTile] — inherits header layout from [ListTileThemeData]
and expansion styling from [ExpansionTileThemeData].

Presentation-only — takes all state via constructor params.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ChallengeCategoryTileScenario =
    Scenario<ChallengeCategoryTile, ChallengeCategoryTileArgs>;
typedef ChallengeCategoryTileDefaults =
    Defaults<ChallengeCategoryTile, ChallengeCategoryTileArgs>;

class ChallengeCategoryTileStory
    extends Story<ChallengeCategoryTile, ChallengeCategoryTileArgs> {
  ChallengeCategoryTileStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ChallengeCategoryTile, ChallengeCategoryTileArgs>?
    builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => ChallengeCategoryTile(
               key: args.key,
               categoryIcon: args.categoryIcon,
               categoryName: args.categoryName,
               remainingCount: args.remainingCount,
               completedCount: args.completedCount,
               pointsLabel: args.pointsLabel,
               challenges: args.challenges,
               initiallyExpanded: args.initiallyExpanded,
               onExpansionChanged: args.onExpansionChanged,
             ),
       );
}

class ChallengeCategoryTileArgs extends StoryArgs<ChallengeCategoryTile> {
  ChallengeCategoryTileArgs({
    Arg<Key?>? key,
    required Arg<Widget> categoryIcon,
    Arg<String>? categoryName,
    Arg<int>? remainingCount,
    Arg<int>? completedCount,
    Arg<String>? pointsLabel,
    required Arg<List<ChallengeCategoryItem>> challenges,
    Arg<bool>? initiallyExpanded,
    Arg<void Function(bool)?>? onExpansionChanged,
  }) : this.keyArg = $initArg('key', key, null),
       this.categoryIconArg = $initArg('categoryIcon', categoryIcon, null)!,
       this.categoryNameArg = $initArg(
         'categoryName',
         categoryName,
         StringArg(''),
       )!,
       this.remainingCountArg = $initArg(
         'remainingCount',
         remainingCount,
         IntArg(0),
       )!,
       this.completedCountArg = $initArg(
         'completedCount',
         completedCount,
         IntArg(0),
       )!,
       this.pointsLabelArg = $initArg(
         'pointsLabel',
         pointsLabel,
         StringArg(''),
       )!,
       this.challengesArg = $initArg('challenges', challenges, null)!,
       this.initiallyExpandedArg = $initArg(
         'initiallyExpanded',
         initiallyExpanded,
         BoolArg(false),
       )!,
       this.onExpansionChangedArg = $initArg(
         'onExpansionChanged',
         onExpansionChanged,
         null,
       );

  ChallengeCategoryTileArgs.fixed({
    Key? key,
    required Widget categoryIcon,
    String categoryName = '',
    int remainingCount = 0,
    int completedCount = 0,
    String pointsLabel = '',
    required List<ChallengeCategoryItem> challenges,
    bool initiallyExpanded = false,
    void Function(bool)? onExpansionChanged,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.categoryIconArg = Arg.fixed(categoryIcon),
       this.categoryNameArg = Arg.fixed(categoryName),
       this.remainingCountArg = Arg.fixed(remainingCount),
       this.completedCountArg = Arg.fixed(completedCount),
       this.pointsLabelArg = Arg.fixed(pointsLabel),
       this.challengesArg = Arg.fixed(challenges),
       this.initiallyExpandedArg = Arg.fixed(initiallyExpanded),
       this.onExpansionChangedArg = onExpansionChanged == null
           ? null
           : Arg.fixed(onExpansionChanged);

  final Arg<Key?>? keyArg;

  final Arg<Widget> categoryIconArg;

  final Arg<String> categoryNameArg;

  final Arg<int> remainingCountArg;

  final Arg<int> completedCountArg;

  final Arg<String> pointsLabelArg;

  final Arg<List<ChallengeCategoryItem>> challengesArg;

  final Arg<bool> initiallyExpandedArg;

  final Arg<void Function(bool)?>? onExpansionChangedArg;

  Key? get key => keyArg?.value;

  Widget get categoryIcon => categoryIconArg.value;

  String get categoryName => categoryNameArg.value;

  int get remainingCount => remainingCountArg.value;

  int get completedCount => completedCountArg.value;

  String get pointsLabel => pointsLabelArg.value;

  List<ChallengeCategoryItem> get challenges => challengesArg.value;

  bool get initiallyExpanded => initiallyExpandedArg.value;

  void Function(bool)? get onExpansionChanged => onExpansionChangedArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    categoryIconArg,
    categoryNameArg,
    remainingCountArg,
    completedCountArg,
    pointsLabelArg,
    challengesArg,
    initiallyExpandedArg,
    onExpansionChangedArg,
  ];
}
