// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ChallengeCard, ChallengeCardArgs>;
typedef _Scenario = ChallengeCardScenario;
typedef _Defaults = ChallengeCardDefaults;
typedef _Story = ChallengeCardStory;
typedef _Args = ChallengeCardArgs;
final ChallengeCardComponent = Component<ChallengeCard, ChallengeCardArgs>(
  name: meta.name ?? 'ChallengeCard',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: null,
  stories: [
    $Default..$generatedName = 'Default',
    $Ongoing..$generatedName = 'Ongoing',
    $Completed..$generatedName = 'Completed',
    $Missed..$generatedName = 'Missed',
  ],
);
typedef ChallengeCardScenario = Scenario<ChallengeCard, ChallengeCardArgs>;
typedef ChallengeCardDefaults = Defaults<ChallengeCard, ChallengeCardArgs>;

class ChallengeCardStory extends Story<ChallengeCard, ChallengeCardArgs> {
  ChallengeCardStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ChallengeCard, ChallengeCardArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => ChallengeCard(
               key: args.key,
               title: args.title,
               description: args.description,
               dateRange: args.dateRange,
               category: args.category,
               categoryIcon: args.categoryIcon,
               variant: args.variant,
               rewardIcon: args.rewardIcon,
               rewardText: args.rewardText,
               earnedText: args.earnedText,
               earnedPoints: args.earnedPoints,
               epochPoints: args.epochPoints,
               completedPoints: args.completedPoints,
               onTap: args.onTap,
             ),
       );
}

class ChallengeCardArgs extends StoryArgs<ChallengeCard> {
  ChallengeCardArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<String>? description,
    Arg<String>? dateRange,
    Arg<ChallengeCategory>? category,
    required Arg<Widget> categoryIcon,
    Arg<ChallengeCardVariant>? variant,
    Arg<IconData?>? rewardIcon,
    Arg<String?>? rewardText,
    Arg<String?>? earnedText,
    Arg<String?>? earnedPoints,
    Arg<String?>? epochPoints,
    Arg<String?>? completedPoints,
    Arg<void Function()?>? onTap,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.descriptionArg = $initArg(
         'description',
         description,
         StringArg(''),
       )!,
       this.dateRangeArg = $initArg('dateRange', dateRange, StringArg(''))!,
       this.categoryArg = $initArg(
         'category',
         category,
         EnumArg<ChallengeCategory>(
           ChallengeCategory.technical,
           values: ChallengeCategory.values,
         ),
       )!,
       this.categoryIconArg = $initArg('categoryIcon', categoryIcon, null)!,
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ChallengeCardVariant>(
           ChallengeCardVariant.active,
           values: ChallengeCardVariant.values,
         ),
       )!,
       this.rewardIconArg = $initArg('rewardIcon', rewardIcon, null),
       this.rewardTextArg = $initArg(
         'rewardText',
         rewardText,
         NullableStringArg(null),
       )!,
       this.earnedTextArg = $initArg(
         'earnedText',
         earnedText,
         NullableStringArg(null),
       )!,
       this.earnedPointsArg = $initArg(
         'earnedPoints',
         earnedPoints,
         NullableStringArg(null),
       )!,
       this.epochPointsArg = $initArg(
         'epochPoints',
         epochPoints,
         NullableStringArg(null),
       )!,
       this.completedPointsArg = $initArg(
         'completedPoints',
         completedPoints,
         NullableStringArg(null),
       )!,
       this.onTapArg = $initArg('onTap', onTap, null);

  ChallengeCardArgs.fixed({
    Key? key,
    String title = '',
    String description = '',
    String dateRange = '',
    ChallengeCategory category = ChallengeCategory.technical,
    required Widget categoryIcon,
    ChallengeCardVariant variant = ChallengeCardVariant.active,
    IconData? rewardIcon,
    String? rewardText = null,
    String? earnedText = null,
    String? earnedPoints = null,
    String? epochPoints = null,
    String? completedPoints = null,
    void Function()? onTap,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.descriptionArg = Arg.fixed(description),
       this.dateRangeArg = Arg.fixed(dateRange),
       this.categoryArg = Arg.fixed(category),
       this.categoryIconArg = Arg.fixed(categoryIcon),
       this.variantArg = Arg.fixed(variant),
       this.rewardIconArg = rewardIcon == null ? null : Arg.fixed(rewardIcon),
       this.rewardTextArg = rewardText == null ? null : Arg.fixed(rewardText),
       this.earnedTextArg = earnedText == null ? null : Arg.fixed(earnedText),
       this.earnedPointsArg = earnedPoints == null
           ? null
           : Arg.fixed(earnedPoints),
       this.epochPointsArg = epochPoints == null
           ? null
           : Arg.fixed(epochPoints),
       this.completedPointsArg = completedPoints == null
           ? null
           : Arg.fixed(completedPoints),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<String> descriptionArg;

  final Arg<String> dateRangeArg;

  final Arg<ChallengeCategory> categoryArg;

  final Arg<Widget> categoryIconArg;

  final Arg<ChallengeCardVariant> variantArg;

  final Arg<IconData?>? rewardIconArg;

  final Arg<String?>? rewardTextArg;

  final Arg<String?>? earnedTextArg;

  final Arg<String?>? earnedPointsArg;

  final Arg<String?>? epochPointsArg;

  final Arg<String?>? completedPointsArg;

  final Arg<void Function()?>? onTapArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  String get description => descriptionArg.value;

  String get dateRange => dateRangeArg.value;

  ChallengeCategory get category => categoryArg.value;

  Widget get categoryIcon => categoryIconArg.value;

  ChallengeCardVariant get variant => variantArg.value;

  IconData? get rewardIcon => rewardIconArg?.value;

  String? get rewardText => rewardTextArg?.value;

  String? get earnedText => earnedTextArg?.value;

  String? get earnedPoints => earnedPointsArg?.value;

  String? get epochPoints => epochPointsArg?.value;

  String? get completedPoints => completedPointsArg?.value;

  void Function()? get onTap => onTapArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    descriptionArg,
    dateRangeArg,
    categoryArg,
    categoryIconArg,
    variantArg,
    rewardIconArg,
    rewardTextArg,
    earnedTextArg,
    earnedPointsArg,
    epochPointsArg,
    completedPointsArg,
    onTapArg,
  ];
}
