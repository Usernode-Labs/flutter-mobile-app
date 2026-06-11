// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_detail_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ChallengeDetailPage, ChallengeDetailPageArgs>;
typedef _Scenario = ChallengeDetailPageScenario;
typedef _Defaults = ChallengeDetailPageDefaults;
typedef _Story = ChallengeDetailPageStory;
typedef _Args = ChallengeDetailPageArgs;
final ChallengeDetailPageComponent =
    Component<ChallengeDetailPage, ChallengeDetailPageArgs>(
      name: meta.name ?? 'ChallengeDetailPage',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: r'''A full-page detail view for a blockchain challenge.

Renders a [TopAppBar] (large) with category icon, title, and subtitle,
followed by a reward card, description sections, and a total reward card.
When [ctaLabel] and [onCtaTap] are both provided, also renders a pinned
primary CTA button in the bottom navigation bar.

This is a presentation-only widget: all data comes through constructor
parameters. The feature screen in `lib/features/` wires state to this widget.''',
      stories: [
        $Default..$generatedName = 'Default',
        $WithStatusSection..$generatedName = 'WithStatusSection',
        $Minimal..$generatedName = 'Minimal',
      ],
    );
typedef ChallengeDetailPageScenario =
    Scenario<ChallengeDetailPage, ChallengeDetailPageArgs>;
typedef ChallengeDetailPageDefaults =
    Defaults<ChallengeDetailPage, ChallengeDetailPageArgs>;

class ChallengeDetailPageStory
    extends Story<ChallengeDetailPage, ChallengeDetailPageArgs> {
  ChallengeDetailPageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ChallengeDetailPage, ChallengeDetailPageArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => ChallengeDetailPage(
               key: args.key,
               title: args.title,
               category: args.category,
               dateRange: args.dateRange,
               rewardCard: args.rewardCard,
               statusSection: args.statusSection,
               sections: args.sections,
               totalRewardHeading: args.totalRewardHeading,
               totalRewardBody: args.totalRewardBody,
               pointsBreakdown: args.pointsBreakdown,
               pointsBreakdownTotal: args.pointsBreakdownTotal,
               onBackTap: args.onBackTap,
               ctaLabel: args.ctaLabel,
               onCtaTap: args.onCtaTap,
             ),
       );
}

class ChallengeDetailPageArgs extends StoryArgs<ChallengeDetailPage> {
  ChallengeDetailPageArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<ChallengeCategory>? category,
    Arg<String>? dateRange,
    Arg<Widget?>? rewardCard,
    Arg<Widget?>? statusSection,
    required Arg<List<({String body, String title})>> sections,
    Arg<String?>? totalRewardHeading,
    Arg<String?>? totalRewardBody,
    Arg<List<({String? date, String description, String points})>>?
    pointsBreakdown,
    Arg<String?>? pointsBreakdownTotal,
    Arg<void Function()?>? onBackTap,
    Arg<String?>? ctaLabel,
    Arg<void Function()?>? onCtaTap,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.categoryArg = $initArg(
         'category',
         category,
         EnumArg<ChallengeCategory>(
           ChallengeCategory.technical,
           values: ChallengeCategory.values,
         ),
       )!,
       this.dateRangeArg = $initArg('dateRange', dateRange, StringArg(''))!,
       this.rewardCardArg = $initArg('rewardCard', rewardCard, null),
       this.statusSectionArg = $initArg('statusSection', statusSection, null),
       this.sectionsArg = $initArg('sections', sections, null)!,
       this.totalRewardHeadingArg = $initArg(
         'totalRewardHeading',
         totalRewardHeading,
         NullableStringArg(null),
       )!,
       this.totalRewardBodyArg = $initArg(
         'totalRewardBody',
         totalRewardBody,
         NullableStringArg(null),
       )!,
       this.pointsBreakdownArg = $initArg(
         'pointsBreakdown',
         pointsBreakdown,
         ConstArg(const <ChallengePointEntry>[]),
       )!,
       this.pointsBreakdownTotalArg = $initArg(
         'pointsBreakdownTotal',
         pointsBreakdownTotal,
         NullableStringArg(null),
       )!,
       this.onBackTapArg = $initArg('onBackTap', onBackTap, null),
       this.ctaLabelArg = $initArg(
         'ctaLabel',
         ctaLabel,
         NullableStringArg(null),
       )!,
       this.onCtaTapArg = $initArg('onCtaTap', onCtaTap, null);

  ChallengeDetailPageArgs.fixed({
    Key? key,
    String title = '',
    ChallengeCategory category = ChallengeCategory.technical,
    String dateRange = '',
    Widget? rewardCard,
    Widget? statusSection,
    required List<({String body, String title})> sections,
    String? totalRewardHeading = null,
    String? totalRewardBody = null,
    List<({String? date, String description, String points})> pointsBreakdown =
        const <ChallengePointEntry>[],
    String? pointsBreakdownTotal = null,
    void Function()? onBackTap,
    String? ctaLabel = null,
    void Function()? onCtaTap,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.categoryArg = Arg.fixed(category),
       this.dateRangeArg = Arg.fixed(dateRange),
       this.rewardCardArg = rewardCard == null ? null : Arg.fixed(rewardCard),
       this.statusSectionArg = statusSection == null
           ? null
           : Arg.fixed(statusSection),
       this.sectionsArg = Arg.fixed(sections),
       this.totalRewardHeadingArg = totalRewardHeading == null
           ? null
           : Arg.fixed(totalRewardHeading),
       this.totalRewardBodyArg = totalRewardBody == null
           ? null
           : Arg.fixed(totalRewardBody),
       this.pointsBreakdownArg = Arg.fixed(pointsBreakdown),
       this.pointsBreakdownTotalArg = pointsBreakdownTotal == null
           ? null
           : Arg.fixed(pointsBreakdownTotal),
       this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap),
       this.ctaLabelArg = ctaLabel == null ? null : Arg.fixed(ctaLabel),
       this.onCtaTapArg = onCtaTap == null ? null : Arg.fixed(onCtaTap);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<ChallengeCategory> categoryArg;

  final Arg<String> dateRangeArg;

  final Arg<Widget?>? rewardCardArg;

  final Arg<Widget?>? statusSectionArg;

  final Arg<List<({String body, String title})>> sectionsArg;

  final Arg<String?>? totalRewardHeadingArg;

  final Arg<String?>? totalRewardBodyArg;

  final Arg<List<({String? date, String description, String points})>>
  pointsBreakdownArg;

  final Arg<String?>? pointsBreakdownTotalArg;

  final Arg<void Function()?>? onBackTapArg;

  final Arg<String?>? ctaLabelArg;

  final Arg<void Function()?>? onCtaTapArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  ChallengeCategory get category => categoryArg.value;

  String get dateRange => dateRangeArg.value;

  Widget? get rewardCard => rewardCardArg?.value;

  Widget? get statusSection => statusSectionArg?.value;

  List<({String body, String title})> get sections => sectionsArg.value;

  String? get totalRewardHeading => totalRewardHeadingArg?.value;

  String? get totalRewardBody => totalRewardBodyArg?.value;

  List<({String? date, String description, String points})>
  get pointsBreakdown => pointsBreakdownArg.value;

  String? get pointsBreakdownTotal => pointsBreakdownTotalArg?.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  String? get ctaLabel => ctaLabelArg?.value;

  void Function()? get onCtaTap => onCtaTapArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    categoryArg,
    dateRangeArg,
    rewardCardArg,
    statusSectionArg,
    sectionsArg,
    totalRewardHeadingArg,
    totalRewardBodyArg,
    pointsBreakdownArg,
    pointsBreakdownTotalArg,
    onBackTapArg,
    ctaLabelArg,
    onCtaTapArg,
  ];
}
