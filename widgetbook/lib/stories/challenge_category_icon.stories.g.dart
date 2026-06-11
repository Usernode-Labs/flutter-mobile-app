// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_category_icon.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component
    = Component<ChallengeCategoryIcon, ChallengeCategoryIconArgs>;
typedef _Scenario = ChallengeCategoryIconScenario;
typedef _Defaults = ChallengeCategoryIconDefaults;
typedef _Story = ChallengeCategoryIconStory;
typedef _Args = ChallengeCategoryIconArgs;
final ChallengeCategoryIconComponent =
    Component<ChallengeCategoryIcon, ChallengeCategoryIconArgs>(
  name: meta.name ?? 'ChallengeCategoryIcon',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''Renders the abstract geometric icon for a [ChallengeCategory].

Each category has a unique shape (polygon, cookie, circle) rendered via
[CustomPainter] with three colour layers derived from the category's
semantic colour group: outer fill at [SemanticColorGroup.colorSurface],
inner fill at [SemanticColorGroup.colorContainer], and a fully-saturated
stroke outline at [SemanticColorGroup.color].

When [muted] is `true` the category colour is replaced with neutral surface
tones (`surfaceDim` for fills, `outline` for strokes) — useful for missed
or inactive states.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Muted..$generatedName = 'Muted',
  ],
);
typedef ChallengeCategoryIconScenario
    = Scenario<ChallengeCategoryIcon, ChallengeCategoryIconArgs>;
typedef ChallengeCategoryIconDefaults
    = Defaults<ChallengeCategoryIcon, ChallengeCategoryIconArgs>;

class ChallengeCategoryIconStory
    extends Story<ChallengeCategoryIcon, ChallengeCategoryIconArgs> {
  ChallengeCategoryIconStory({
    super.name,
    super.setup,
    super.modes,
    ChallengeCategoryIconArgs? args,
    StoryWidgetBuilder<ChallengeCategoryIcon, ChallengeCategoryIconArgs>?
        builder,
    super.scenarios,
  }) : super(
          args: args ?? ChallengeCategoryIconArgs(),
          builder: builder ??
              (context, args) => ChallengeCategoryIcon(
                    key: args.key,
                    category: args.category,
                    size: args.size,
                    muted: args.muted,
                  ),
        );
}

class ChallengeCategoryIconArgs extends StoryArgs<ChallengeCategoryIcon> {
  ChallengeCategoryIconArgs({
    Arg<Key?>? key,
    Arg<ChallengeCategory>? category,
    Arg<double?>? size,
    Arg<bool>? muted,
  })  : this.keyArg = $initArg('key', key, null),
        this.categoryArg = $initArg(
          'category',
          category,
          EnumArg<ChallengeCategory>(
            ChallengeCategory.technical,
            values: ChallengeCategory.values,
          ),
        )!,
        this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!,
        this.mutedArg = $initArg('muted', muted, BoolArg(false))!;

  ChallengeCategoryIconArgs.fixed({
    Key? key,
    ChallengeCategory category = ChallengeCategory.technical,
    double? size = null,
    bool muted = false,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.categoryArg = Arg.fixed(category),
        this.sizeArg = size == null ? null : Arg.fixed(size),
        this.mutedArg = Arg.fixed(muted);

  final Arg<Key?>? keyArg;

  final Arg<ChallengeCategory> categoryArg;

  final Arg<double?>? sizeArg;

  final Arg<bool> mutedArg;

  Key? get key => keyArg?.value;

  ChallengeCategory get category => categoryArg.value;

  double? get size => sizeArg?.value;

  bool get muted => mutedArg.value;

  @override
  List<Arg?> get list => [keyArg, categoryArg, sizeArg, mutedArg];
}
