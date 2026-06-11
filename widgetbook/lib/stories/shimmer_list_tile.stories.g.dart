// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'shimmer_list_tile.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ShimmerListTile, ShimmerListTileArgs>;
typedef _Scenario = ShimmerListTileScenario;
typedef _Defaults = ShimmerListTileDefaults;
typedef _Story = ShimmerListTileStory;
typedef _Args = ShimmerListTileArgs;
final ShimmerListTileComponent =
    Component<ShimmerListTile, ShimmerListTileArgs>(
  name: meta.name ?? 'ShimmerListTile',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A skeleton placeholder shaped like a [ListTile] with an [IconBadge]-sized
leading element.

Composes [ShimmerBlock] instances to match the visual structure of a
three-line list tile, giving users spatial context during data loading.

Uses [Padding] matching [ListTile] content padding for visual consistency
with real tiles.''',
  stories: [
    $Default..$generatedName = 'Default',
    $TwoLine..$generatedName = 'TwoLine',
    $NoTrailing..$generatedName = 'NoTrailing',
  ],
);
typedef ShimmerListTileScenario
    = Scenario<ShimmerListTile, ShimmerListTileArgs>;
typedef ShimmerListTileDefaults
    = Defaults<ShimmerListTile, ShimmerListTileArgs>;

class ShimmerListTileStory extends Story<ShimmerListTile, ShimmerListTileArgs> {
  ShimmerListTileStory({
    super.name,
    super.setup,
    super.modes,
    ShimmerListTileArgs? args,
    StoryWidgetBuilder<ShimmerListTile, ShimmerListTileArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? ShimmerListTileArgs(),
          builder: builder ??
              (context, args) => ShimmerListTile(
                    key: args.key,
                    isThreeLine: args.isThreeLine,
                    hasTrailing: args.hasTrailing,
                  ),
        );
}

class ShimmerListTileArgs extends StoryArgs<ShimmerListTile> {
  ShimmerListTileArgs({
    Arg<Key?>? key,
    Arg<bool>? isThreeLine,
    Arg<bool>? hasTrailing,
  })  : this.keyArg = $initArg('key', key, null),
        this.isThreeLineArg = $initArg(
          'isThreeLine',
          isThreeLine,
          BoolArg(true),
        )!,
        this.hasTrailingArg = $initArg(
          'hasTrailing',
          hasTrailing,
          BoolArg(true),
        )!;

  ShimmerListTileArgs.fixed({
    Key? key,
    bool isThreeLine = true,
    bool hasTrailing = true,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.isThreeLineArg = Arg.fixed(isThreeLine),
        this.hasTrailingArg = Arg.fixed(hasTrailing);

  final Arg<Key?>? keyArg;

  final Arg<bool> isThreeLineArg;

  final Arg<bool> hasTrailingArg;

  Key? get key => keyArg?.value;

  bool get isThreeLine => isThreeLineArg.value;

  bool get hasTrailing => hasTrailingArg.value;

  @override
  List<Arg?> get list => [keyArg, isThreeLineArg, hasTrailingArg];
}
