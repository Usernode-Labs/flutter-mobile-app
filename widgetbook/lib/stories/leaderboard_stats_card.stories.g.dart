// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'leaderboard_stats_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<LeaderboardStatsCard, LeaderboardStatsCardArgs>;
typedef _Scenario = LeaderboardStatsCardScenario;
typedef _Defaults = LeaderboardStatsCardDefaults;
typedef _Story = LeaderboardStatsCardStory;
typedef _Args = LeaderboardStatsCardArgs;
final LeaderboardStatsCardComponent =
    Component<LeaderboardStatsCard, LeaderboardStatsCardArgs>(
      name: meta.name ?? 'LeaderboardStatsCard',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A stats summary card with dot-matrix distribution chart for the leaderboard.

Composes three private sub-widgets:
- `_StatBox` — bordered container with uppercase label + monospace value
- `_DotMatrixChart` — achromatic scatter plot with x-axis labels
- `_ExplainerCallout` — contextual card with icon + dynamic messaging

Presentation-only — takes all state via constructor params.
Manages local UI state for bucket selection (tap to explore).''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef LeaderboardStatsCardScenario =
    Scenario<LeaderboardStatsCard, LeaderboardStatsCardArgs>;
typedef LeaderboardStatsCardDefaults =
    Defaults<LeaderboardStatsCard, LeaderboardStatsCardArgs>;

class LeaderboardStatsCardStory
    extends Story<LeaderboardStatsCard, LeaderboardStatsCardArgs> {
  LeaderboardStatsCardStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<LeaderboardStatsCard, LeaderboardStatsCardArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => LeaderboardStatsCard(
               key: args.key,
               totalPoints: args.totalPoints,
               totalPointsLabel: args.totalPointsLabel,
               rank: args.rank,
               rankLabel: args.rankLabel,
               distributionCounts: args.distributionCounts,
               userBucketIndex: args.userBucketIndex,
               minScoreLabel: args.minScoreLabel,
               userScoreLabel: args.userScoreLabel,
               maxScoreLabel: args.maxScoreLabel,
               calloutTitle: args.calloutTitle,
               calloutBody: args.calloutBody,
               bucketScoreLabels: args.bucketScoreLabels,
               onBucketTapped: args.onBucketTapped,
             ),
       );
}

class LeaderboardStatsCardArgs extends StoryArgs<LeaderboardStatsCard> {
  LeaderboardStatsCardArgs({
    Arg<Key?>? key,
    Arg<String>? totalPoints,
    Arg<String>? totalPointsLabel,
    Arg<String>? rank,
    Arg<String>? rankLabel,
    required Arg<List<int>> distributionCounts,
    Arg<int>? userBucketIndex,
    Arg<String?>? minScoreLabel,
    Arg<String?>? userScoreLabel,
    Arg<String?>? maxScoreLabel,
    Arg<String?>? calloutTitle,
    Arg<String?>? calloutBody,
    Arg<List<String>?>? bucketScoreLabels,
    Arg<void Function(int?)?>? onBucketTapped,
  }) : this.keyArg = $initArg('key', key, null),
       this.totalPointsArg = $initArg(
         'totalPoints',
         totalPoints,
         StringArg(''),
       )!,
       this.totalPointsLabelArg = $initArg(
         'totalPointsLabel',
         totalPointsLabel,
         StringArg(''),
       )!,
       this.rankArg = $initArg('rank', rank, StringArg(''))!,
       this.rankLabelArg = $initArg('rankLabel', rankLabel, StringArg(''))!,
       this.distributionCountsArg = $initArg(
         'distributionCounts',
         distributionCounts,
         null,
       )!,
       this.userBucketIndexArg = $initArg(
         'userBucketIndex',
         userBucketIndex,
         IntArg(0),
       )!,
       this.minScoreLabelArg = $initArg(
         'minScoreLabel',
         minScoreLabel,
         NullableStringArg(null),
       )!,
       this.userScoreLabelArg = $initArg(
         'userScoreLabel',
         userScoreLabel,
         NullableStringArg(null),
       )!,
       this.maxScoreLabelArg = $initArg(
         'maxScoreLabel',
         maxScoreLabel,
         NullableStringArg(null),
       )!,
       this.calloutTitleArg = $initArg(
         'calloutTitle',
         calloutTitle,
         NullableStringArg(null),
       )!,
       this.calloutBodyArg = $initArg(
         'calloutBody',
         calloutBody,
         NullableStringArg(null),
       )!,
       this.bucketScoreLabelsArg = $initArg(
         'bucketScoreLabels',
         bucketScoreLabels,
         null,
       ),
       this.onBucketTappedArg = $initArg(
         'onBucketTapped',
         onBucketTapped,
         null,
       );

  LeaderboardStatsCardArgs.fixed({
    Key? key,
    String totalPoints = '',
    String totalPointsLabel = '',
    String rank = '',
    String rankLabel = '',
    required List<int> distributionCounts,
    int userBucketIndex = 0,
    String? minScoreLabel = null,
    String? userScoreLabel = null,
    String? maxScoreLabel = null,
    String? calloutTitle = null,
    String? calloutBody = null,
    List<String>? bucketScoreLabels,
    void Function(int?)? onBucketTapped,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.totalPointsArg = Arg.fixed(totalPoints),
       this.totalPointsLabelArg = Arg.fixed(totalPointsLabel),
       this.rankArg = Arg.fixed(rank),
       this.rankLabelArg = Arg.fixed(rankLabel),
       this.distributionCountsArg = Arg.fixed(distributionCounts),
       this.userBucketIndexArg = Arg.fixed(userBucketIndex),
       this.minScoreLabelArg = minScoreLabel == null
           ? null
           : Arg.fixed(minScoreLabel),
       this.userScoreLabelArg = userScoreLabel == null
           ? null
           : Arg.fixed(userScoreLabel),
       this.maxScoreLabelArg = maxScoreLabel == null
           ? null
           : Arg.fixed(maxScoreLabel),
       this.calloutTitleArg = calloutTitle == null
           ? null
           : Arg.fixed(calloutTitle),
       this.calloutBodyArg = calloutBody == null
           ? null
           : Arg.fixed(calloutBody),
       this.bucketScoreLabelsArg = bucketScoreLabels == null
           ? null
           : Arg.fixed(bucketScoreLabels),
       this.onBucketTappedArg = onBucketTapped == null
           ? null
           : Arg.fixed(onBucketTapped);

  final Arg<Key?>? keyArg;

  final Arg<String> totalPointsArg;

  final Arg<String> totalPointsLabelArg;

  final Arg<String> rankArg;

  final Arg<String> rankLabelArg;

  final Arg<List<int>> distributionCountsArg;

  final Arg<int> userBucketIndexArg;

  final Arg<String?>? minScoreLabelArg;

  final Arg<String?>? userScoreLabelArg;

  final Arg<String?>? maxScoreLabelArg;

  final Arg<String?>? calloutTitleArg;

  final Arg<String?>? calloutBodyArg;

  final Arg<List<String>?>? bucketScoreLabelsArg;

  final Arg<void Function(int?)?>? onBucketTappedArg;

  Key? get key => keyArg?.value;

  String get totalPoints => totalPointsArg.value;

  String get totalPointsLabel => totalPointsLabelArg.value;

  String get rank => rankArg.value;

  String get rankLabel => rankLabelArg.value;

  List<int> get distributionCounts => distributionCountsArg.value;

  int get userBucketIndex => userBucketIndexArg.value;

  String? get minScoreLabel => minScoreLabelArg?.value;

  String? get userScoreLabel => userScoreLabelArg?.value;

  String? get maxScoreLabel => maxScoreLabelArg?.value;

  String? get calloutTitle => calloutTitleArg?.value;

  String? get calloutBody => calloutBodyArg?.value;

  List<String>? get bucketScoreLabels => bucketScoreLabelsArg?.value;

  void Function(int?)? get onBucketTapped => onBucketTappedArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    totalPointsArg,
    totalPointsLabelArg,
    rankArg,
    rankLabelArg,
    distributionCountsArg,
    userBucketIndexArg,
    minScoreLabelArg,
    userScoreLabelArg,
    maxScoreLabelArg,
    calloutTitleArg,
    calloutBodyArg,
    bucketScoreLabelsArg,
    onBucketTappedArg,
  ];
}
