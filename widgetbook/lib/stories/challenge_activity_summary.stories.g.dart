// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_activity_summary.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ChallengeActivitySummary, ChallengeActivitySummaryArgs>;
typedef _Scenario = ChallengeActivitySummaryScenario;
typedef _Defaults = ChallengeActivitySummaryDefaults;
typedef _Story = ChallengeActivitySummaryStory;
typedef _Args = ChallengeActivitySummaryArgs;
final ChallengeActivitySummaryComponent =
    Component<ChallengeActivitySummary, ChallengeActivitySummaryArgs>(
      name: meta.name ?? 'ChallengeActivitySummary',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $NoChallenges..$generatedName = 'NoChallenges',
      ],
    );
typedef ChallengeActivitySummaryScenario =
    Scenario<ChallengeActivitySummary, ChallengeActivitySummaryArgs>;
typedef ChallengeActivitySummaryDefaults =
    Defaults<ChallengeActivitySummary, ChallengeActivitySummaryArgs>;

class ChallengeActivitySummaryStory
    extends Story<ChallengeActivitySummary, ChallengeActivitySummaryArgs> {
  ChallengeActivitySummaryStory({
    super.name,
    super.setup,
    super.modes,
    ChallengeActivitySummaryArgs? args,
    StoryWidgetBuilder<ChallengeActivitySummary, ChallengeActivitySummaryArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? ChallengeActivitySummaryArgs(),
         builder:
             builder ??
             (context, args) => ChallengeActivitySummary(
               key: args.key,
               completedCount: args.completedCount,
               missedCount: args.missedCount,
               totalCount: args.totalCount,
               onViewCompleted: args.onViewCompleted,
               onViewMissed: args.onViewMissed,
             ),
       );
}

class ChallengeActivitySummaryArgs extends StoryArgs<ChallengeActivitySummary> {
  ChallengeActivitySummaryArgs({
    Arg<Key?>? key,
    Arg<int>? completedCount,
    Arg<int>? missedCount,
    Arg<int>? totalCount,
    Arg<void Function()?>? onViewCompleted,
    Arg<void Function()?>? onViewMissed,
  }) : this.keyArg = $initArg('key', key, null),
       this.completedCountArg = $initArg(
         'completedCount',
         completedCount,
         IntArg(0),
       )!,
       this.missedCountArg = $initArg('missedCount', missedCount, IntArg(0))!,
       this.totalCountArg = $initArg('totalCount', totalCount, IntArg(0))!,
       this.onViewCompletedArg = $initArg(
         'onViewCompleted',
         onViewCompleted,
         null,
       ),
       this.onViewMissedArg = $initArg('onViewMissed', onViewMissed, null);

  ChallengeActivitySummaryArgs.fixed({
    Key? key,
    int completedCount = 0,
    int missedCount = 0,
    int totalCount = 0,
    void Function()? onViewCompleted,
    void Function()? onViewMissed,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.completedCountArg = Arg.fixed(completedCount),
       this.missedCountArg = Arg.fixed(missedCount),
       this.totalCountArg = Arg.fixed(totalCount),
       this.onViewCompletedArg = onViewCompleted == null
           ? null
           : Arg.fixed(onViewCompleted),
       this.onViewMissedArg = onViewMissed == null
           ? null
           : Arg.fixed(onViewMissed);

  final Arg<Key?>? keyArg;

  final Arg<int> completedCountArg;

  final Arg<int> missedCountArg;

  final Arg<int> totalCountArg;

  final Arg<void Function()?>? onViewCompletedArg;

  final Arg<void Function()?>? onViewMissedArg;

  Key? get key => keyArg?.value;

  int get completedCount => completedCountArg.value;

  int get missedCount => missedCountArg.value;

  int get totalCount => totalCountArg.value;

  void Function()? get onViewCompleted => onViewCompletedArg?.value;

  void Function()? get onViewMissed => onViewMissedArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    completedCountArg,
    missedCountArg,
    totalCountArg,
    onViewCompletedArg,
    onViewMissedArg,
  ];
}
