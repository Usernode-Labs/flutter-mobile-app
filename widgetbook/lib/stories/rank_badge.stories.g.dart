// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'rank_badge.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<RankBadge, RankBadgeArgs>;
typedef _Scenario = RankBadgeScenario;
typedef _Defaults = RankBadgeDefaults;
typedef _Story = RankBadgeStory;
typedef _Args = RankBadgeArgs;
final RankBadgeComponent = Component<RankBadge, RankBadgeArgs>(
  name: meta.name ?? 'RankBadge',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A 40px circle showing a rank number, used as a [ListTile.leading] slot
in leaderboard ranking rows.

Uses `surfaceContainerLowest` background with an `outlineVariant` border
and centered rank text in `labelLarge` medium weight.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $LargeRank..$generatedName = 'LargeRank',
  ],
);
typedef RankBadgeScenario = Scenario<RankBadge, RankBadgeArgs>;
typedef RankBadgeDefaults = Defaults<RankBadge, RankBadgeArgs>;

class RankBadgeStory extends Story<RankBadge, RankBadgeArgs> {
  RankBadgeStory({
    super.name,
    super.setup,
    super.modes,
    RankBadgeArgs? args,
    StoryWidgetBuilder<RankBadge, RankBadgeArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? RankBadgeArgs(),
          builder: builder ??
              (context, args) => RankBadge(key: args.key, rank: args.rank),
        );
}

class RankBadgeArgs extends StoryArgs<RankBadge> {
  RankBadgeArgs({Arg<Key?>? key, Arg<String>? rank})
      : this.keyArg = $initArg('key', key, null),
        this.rankArg = $initArg('rank', rank, StringArg(''))!;

  RankBadgeArgs.fixed({Key? key, String rank = ''})
      : this.keyArg = key == null ? null : Arg.fixed(key),
        this.rankArg = Arg.fixed(rank);

  final Arg<Key?>? keyArg;

  final Arg<String> rankArg;

  Key? get key => keyArg?.value;

  String get rank => rankArg.value;

  @override
  List<Arg?> get list => [keyArg, rankArg];
}
