// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'testnet_profile_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<TestnetProfilePageDemo, TestnetProfilePageDemoArgs>;
typedef _Scenario = TestnetProfilePageDemoScenario;
typedef _Defaults = TestnetProfilePageDemoDefaults;
typedef _Story = TestnetProfilePageDemoStory;
typedef _Args = TestnetProfilePageDemoArgs;
final TestnetProfilePageDemoComponent =
    Component<TestnetProfilePageDemo, TestnetProfilePageDemoArgs>(
      name: meta.name ?? 'TestnetProfilePageDemo',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $Default..$generatedName = 'Default',
        $Leaderboard..$generatedName = 'Leaderboard',
      ],
    );
typedef TestnetProfilePageDemoScenario =
    Scenario<TestnetProfilePageDemo, TestnetProfilePageDemoArgs>;
typedef TestnetProfilePageDemoDefaults =
    Defaults<TestnetProfilePageDemo, TestnetProfilePageDemoArgs>;

class TestnetProfilePageDemoStory
    extends Story<TestnetProfilePageDemo, TestnetProfilePageDemoArgs> {
  TestnetProfilePageDemoStory({
    super.name,
    super.setup,
    super.modes,
    TestnetProfilePageDemoArgs? args,
    StoryWidgetBuilder<TestnetProfilePageDemo, TestnetProfilePageDemoArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? TestnetProfilePageDemoArgs(),
         builder:
             builder ??
             (context, args) => TestnetProfilePageDemo(
               key: args.key,
               title: args.title,
               score: args.score,
               scoreLabel: args.scoreLabel,
               rankLabel: args.rankLabel,
               progress: args.progress,
               periodLabel: args.periodLabel,
               completedChallenges: args.completedChallenges,
               rankingEntries: args.rankingEntries,
               initialTabIndex: args.initialTabIndex,
               onBackTap: args.onBackTap,
               onSettingsTap: args.onSettingsTap,
               onPeriodTap: args.onPeriodTap,
             ),
       );
}

class TestnetProfilePageDemoArgs extends StoryArgs<TestnetProfilePageDemo> {
  TestnetProfilePageDemoArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<String>? score,
    Arg<String>? scoreLabel,
    Arg<String?>? rankLabel,
    Arg<double>? progress,
    Arg<String>? periodLabel,
    Arg<List<TestnetProfileChallengeData>>? completedChallenges,
    Arg<List<TestnetProfileRankingEntry>>? rankingEntries,
    Arg<int>? initialTabIndex,
    Arg<void Function()?>? onBackTap,
    Arg<void Function()?>? onSettingsTap,
    Arg<void Function()?>? onPeriodTap,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg('Profile'))!,
       this.scoreArg = $initArg('score', score, StringArg('8,000'))!,
       this.scoreLabelArg = $initArg(
         'scoreLabel',
         scoreLabel,
         StringArg('points'),
       )!,
       this.rankLabelArg = $initArg(
         'rankLabel',
         rankLabel,
         NullableStringArg('Rank 44'),
       )!,
       this.progressArg = $initArg('progress', progress, DoubleArg(0.65))!,
       this.periodLabelArg = $initArg(
         'periodLabel',
         periodLabel,
         StringArg('All Events'),
       )!,
       this.completedChallengesArg = $initArg(
         'completedChallenges',
         completedChallenges,
         ConstArg(_defaultCompletedChallenges),
       )!,
       this.rankingEntriesArg = $initArg(
         'rankingEntries',
         rankingEntries,
         ConstArg(_defaultRankingEntries),
       )!,
       this.initialTabIndexArg = $initArg(
         'initialTabIndex',
         initialTabIndex,
         IntArg(0),
       )!,
       this.onBackTapArg = $initArg('onBackTap', onBackTap, null),
       this.onSettingsTapArg = $initArg('onSettingsTap', onSettingsTap, null),
       this.onPeriodTapArg = $initArg('onPeriodTap', onPeriodTap, null);

  TestnetProfilePageDemoArgs.fixed({
    Key? key,
    String title = 'Profile',
    String score = '8,000',
    String scoreLabel = 'points',
    String? rankLabel = 'Rank 44',
    double progress = 0.65,
    String periodLabel = 'All Events',
    List<TestnetProfileChallengeData> completedChallenges =
        _defaultCompletedChallenges,
    List<TestnetProfileRankingEntry> rankingEntries = _defaultRankingEntries,
    int initialTabIndex = 0,
    void Function()? onBackTap,
    void Function()? onSettingsTap,
    void Function()? onPeriodTap,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.scoreArg = Arg.fixed(score),
       this.scoreLabelArg = Arg.fixed(scoreLabel),
       this.rankLabelArg = rankLabel == null ? null : Arg.fixed(rankLabel),
       this.progressArg = Arg.fixed(progress),
       this.periodLabelArg = Arg.fixed(periodLabel),
       this.completedChallengesArg = Arg.fixed(completedChallenges),
       this.rankingEntriesArg = Arg.fixed(rankingEntries),
       this.initialTabIndexArg = Arg.fixed(initialTabIndex),
       this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap),
       this.onSettingsTapArg = onSettingsTap == null
           ? null
           : Arg.fixed(onSettingsTap),
       this.onPeriodTapArg = onPeriodTap == null
           ? null
           : Arg.fixed(onPeriodTap);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<String> scoreArg;

  final Arg<String> scoreLabelArg;

  final Arg<String?>? rankLabelArg;

  final Arg<double> progressArg;

  final Arg<String> periodLabelArg;

  final Arg<List<TestnetProfileChallengeData>> completedChallengesArg;

  final Arg<List<TestnetProfileRankingEntry>> rankingEntriesArg;

  final Arg<int> initialTabIndexArg;

  final Arg<void Function()?>? onBackTapArg;

  final Arg<void Function()?>? onSettingsTapArg;

  final Arg<void Function()?>? onPeriodTapArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  String get score => scoreArg.value;

  String get scoreLabel => scoreLabelArg.value;

  String? get rankLabel => rankLabelArg?.value;

  double get progress => progressArg.value;

  String get periodLabel => periodLabelArg.value;

  List<TestnetProfileChallengeData> get completedChallenges =>
      completedChallengesArg.value;

  List<TestnetProfileRankingEntry> get rankingEntries =>
      rankingEntriesArg.value;

  int get initialTabIndex => initialTabIndexArg.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  void Function()? get onSettingsTap => onSettingsTapArg?.value;

  void Function()? get onPeriodTap => onPeriodTapArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    scoreArg,
    scoreLabelArg,
    rankLabelArg,
    progressArg,
    periodLabelArg,
    completedChallengesArg,
    rankingEntriesArg,
    initialTabIndexArg,
    onBackTapArg,
    onSettingsTapArg,
    onPeriodTapArg,
  ];
}
