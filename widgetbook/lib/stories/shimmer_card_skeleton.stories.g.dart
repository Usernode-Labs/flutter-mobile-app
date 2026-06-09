// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'shimmer_card_skeleton.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ShimmerCardSkeleton, ShimmerCardSkeletonArgs>;
typedef _Scenario = ShimmerCardSkeletonScenario;
typedef _Defaults = ShimmerCardSkeletonDefaults;
typedef _Story = ShimmerCardSkeletonStory;
typedef _Args = ShimmerCardSkeletonArgs;
final ShimmerCardSkeletonComponent =
    Component<ShimmerCardSkeleton, ShimmerCardSkeletonArgs>(
      name: meta.name ?? 'ShimmerCardSkeleton',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A skeleton placeholder shaped like a [ChallengeCard] with header, title,
description, and reward lines.

Composes [ShimmerBlock] instances inside a bordered [Container] to match
the visual structure of a challenge card, giving users spatial context
during data loading.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ShimmerCardSkeletonScenario =
    Scenario<ShimmerCardSkeleton, ShimmerCardSkeletonArgs>;
typedef ShimmerCardSkeletonDefaults =
    Defaults<ShimmerCardSkeleton, ShimmerCardSkeletonArgs>;

class ShimmerCardSkeletonStory
    extends Story<ShimmerCardSkeleton, ShimmerCardSkeletonArgs> {
  ShimmerCardSkeletonStory({
    super.name,
    super.setup,
    super.modes,
    ShimmerCardSkeletonArgs? args,
    StoryWidgetBuilder<ShimmerCardSkeleton, ShimmerCardSkeletonArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ShimmerCardSkeletonArgs(),
         builder:
             builder ?? (context, args) => ShimmerCardSkeleton(key: args.key),
       );
}

class ShimmerCardSkeletonArgs extends StoryArgs<ShimmerCardSkeleton> {
  ShimmerCardSkeletonArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  ShimmerCardSkeletonArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
