// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_event_group.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ChallengeEventGroup, ChallengeEventGroupArgs>;
typedef _Scenario = ChallengeEventGroupScenario;
typedef _Defaults = ChallengeEventGroupDefaults;
typedef _Story = ChallengeEventGroupStory;
typedef _Args = ChallengeEventGroupArgs;
final ChallengeEventGroupComponent =
    Component<ChallengeEventGroup, ChallengeEventGroupArgs>(
  name: meta.name ?? 'ChallengeEventGroup',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A card that groups challenges by event.

All content is rendered as [ListTile]s — the header has no leading (title
at K₁ = 16dp), challenge rows have a category icon leading (title at
K₂ = 72dp). The keyline shift IS the visual hierarchy — no divider needed.
Points labels share the same trailing keyline for clean column alignment.

Follows the "When Zones Collide" pattern: Card provides vertical-only
inset (`space8`), ListTiles own their `contentPadding` (16h from theme).

Presentation-only — takes all state via constructor params.''',
  stories: [$Default..$generatedName = 'Default'],
);
typedef ChallengeEventGroupScenario
    = Scenario<ChallengeEventGroup, ChallengeEventGroupArgs>;
typedef ChallengeEventGroupDefaults
    = Defaults<ChallengeEventGroup, ChallengeEventGroupArgs>;

class ChallengeEventGroupStory
    extends Story<ChallengeEventGroup, ChallengeEventGroupArgs> {
  ChallengeEventGroupStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ChallengeEventGroup, ChallengeEventGroupArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => ChallengeEventGroup(
                    key: args.key,
                    eventName: args.eventName,
                    dateRange: args.dateRange,
                    pointsLabel: args.pointsLabel,
                    challenges: args.challenges,
                  ),
        );
}

class ChallengeEventGroupArgs extends StoryArgs<ChallengeEventGroup> {
  ChallengeEventGroupArgs({
    Arg<Key?>? key,
    Arg<String>? eventName,
    Arg<String?>? dateRange,
    Arg<String>? pointsLabel,
    required Arg<List<ChallengeEventItem>> challenges,
  })  : this.keyArg = $initArg('key', key, null),
        this.eventNameArg = $initArg('eventName', eventName, StringArg(''))!,
        this.dateRangeArg = $initArg(
          'dateRange',
          dateRange,
          NullableStringArg(null),
        )!,
        this.pointsLabelArg = $initArg(
          'pointsLabel',
          pointsLabel,
          StringArg(''),
        )!,
        this.challengesArg = $initArg('challenges', challenges, null)!;

  ChallengeEventGroupArgs.fixed({
    Key? key,
    String eventName = '',
    String? dateRange = null,
    String pointsLabel = '',
    required List<ChallengeEventItem> challenges,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.eventNameArg = Arg.fixed(eventName),
        this.dateRangeArg = dateRange == null ? null : Arg.fixed(dateRange),
        this.pointsLabelArg = Arg.fixed(pointsLabel),
        this.challengesArg = Arg.fixed(challenges);

  final Arg<Key?>? keyArg;

  final Arg<String> eventNameArg;

  final Arg<String?>? dateRangeArg;

  final Arg<String> pointsLabelArg;

  final Arg<List<ChallengeEventItem>> challengesArg;

  Key? get key => keyArg?.value;

  String get eventName => eventNameArg.value;

  String? get dateRange => dateRangeArg?.value;

  String get pointsLabel => pointsLabelArg.value;

  List<ChallengeEventItem> get challenges => challengesArg.value;

  @override
  List<Arg?> get list => [
        keyArg,
        eventNameArg,
        dateRangeArg,
        pointsLabelArg,
        challengesArg,
      ];
}
