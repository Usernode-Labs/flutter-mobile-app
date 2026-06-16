// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'atomic_challenge_detail_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs>;
typedef _Scenario = AtomicChallengeDetailPageScenario;
typedef _Defaults = AtomicChallengeDetailPageDefaults;
typedef _Story = AtomicChallengeDetailPageStory;
typedef _Args = AtomicChallengeDetailInputArgs;
final AtomicChallengeDetailPageComponent =
    Component<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs>(
      name: meta.name ?? 'AtomicChallengeDetailPage',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: r'''The simplified Fair Rewards challenge detail page.

Keeps the compressed card structure intact — goal first, then the same
[AtomicChallengeRail] — so the page reads as an expansion of the card rather
than a separate backend record view. Supporting copy ("Why it matters",
"Available", "How points work", optional "Rules") sits below the rail, and a
single primary CTA is pinned to the bottom.

Presentation-only: all content arrives via constructor parameters. The
feature screen resolves challenge data, formats the strings, and wires the
back / CTA callbacks.''',
      stories: [$ExpandedAtomic..$generatedName = 'ExpandedAtomic'],
    );
typedef AtomicChallengeDetailPageScenario =
    Scenario<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs>;
typedef AtomicChallengeDetailPageDefaults =
    Defaults<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs>;

class AtomicChallengeDetailPageStory
    extends Story<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs> {
  AtomicChallengeDetailPageStory({
    super.name,
    SetupBuilder<AtomicChallengeDetailPage, AtomicChallengeDetailInputArgs>?
    setup,
    super.modes,
    AtomicChallengeDetailInputArgs? args,
    StoryWidgetBuilder<
      AtomicChallengeDetailPage,
      AtomicChallengeDetailInputArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? AtomicChallengeDetailInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class AtomicChallengeDetailInputArgs
    extends StoryArgs<AtomicChallengeDetailPage> {
  AtomicChallengeDetailInputArgs({
    Arg<String>? title,
    Arg<String>? description,
    Arg<String>? leftText,
    Arg<String>? rightText,
    Arg<AtomicChallengePhase>? phase,
    Arg<double?>? fill,
    Arg<String>? dateText,
    Arg<String>? pointsLogic,
    Arg<String>? ctaLabel,
    Arg<String?>? rules,
    Arg<AtomicChallengeRailTreatment>? railTreatment,
  }) : this.titleArg = $initArg(
         'title',
         title,
         StringArg('Propose an app change'),
       )!,
       this.descriptionArg = $initArg(
         'description',
         description,
         StringArg(
           'Improve an existing dApp and help test the new application layer.',
         ),
       )!,
       this.leftTextArg = $initArg(
         'leftText',
         leftText,
         StringArg('Not done'),
       )!,
       this.rightTextArg = $initArg(
         'rightText',
         rightText,
         StringArg('500 pts'),
       )!,
       this.phaseArg = $initArg(
         'phase',
         phase,
         EnumArg<AtomicChallengePhase>(
           AtomicChallengePhase.open,
           values: AtomicChallengePhase.values,
         ),
       )!,
       this.fillArg = $initArg('fill', fill, NullableDoubleArg(0))!,
       this.dateTextArg = $initArg(
         'dateText',
         dateText,
         StringArg('Jun 4 - Jun 17'),
       )!,
       this.pointsLogicArg = $initArg(
         'pointsLogic',
         pointsLogic,
         StringArg('Earn 500 pts when your proposed change is accepted.'),
       )!,
       this.ctaLabelArg = $initArg(
         'ctaLabel',
         ctaLabel,
         StringArg('Join the challenge'),
       )!,
       this.rulesArg = $initArg('rules', rules, NullableStringArg(null))!,
       this.railTreatmentArg = $initArg(
         'railTreatment',
         railTreatment,
         EnumArg<AtomicChallengeRailTreatment>(
           AtomicChallengeRailTreatment.checkbox,
           values: AtomicChallengeRailTreatment.values,
         ),
       )!;

  AtomicChallengeDetailInputArgs.fixed({
    String title = 'Propose an app change',
    String description =
        'Improve an existing dApp and help test the new application layer.',
    String leftText = 'Not done',
    String rightText = '500 pts',
    AtomicChallengePhase phase = AtomicChallengePhase.open,
    double? fill = 0,
    String dateText = 'Jun 4 - Jun 17',
    String pointsLogic = 'Earn 500 pts when your proposed change is accepted.',
    String ctaLabel = 'Join the challenge',
    String? rules = null,
    AtomicChallengeRailTreatment railTreatment =
        AtomicChallengeRailTreatment.checkbox,
  }) : this.titleArg = Arg.fixed(title),
       this.descriptionArg = Arg.fixed(description),
       this.leftTextArg = Arg.fixed(leftText),
       this.rightTextArg = Arg.fixed(rightText),
       this.phaseArg = Arg.fixed(phase),
       this.fillArg = fill == null ? null : Arg.fixed(fill),
       this.dateTextArg = Arg.fixed(dateText),
       this.pointsLogicArg = Arg.fixed(pointsLogic),
       this.ctaLabelArg = Arg.fixed(ctaLabel),
       this.rulesArg = rules == null ? null : Arg.fixed(rules),
       this.railTreatmentArg = Arg.fixed(railTreatment);

  final Arg<String> titleArg;

  final Arg<String> descriptionArg;

  final Arg<String> leftTextArg;

  final Arg<String> rightTextArg;

  final Arg<AtomicChallengePhase> phaseArg;

  final Arg<double?>? fillArg;

  final Arg<String> dateTextArg;

  final Arg<String> pointsLogicArg;

  final Arg<String> ctaLabelArg;

  final Arg<String?>? rulesArg;

  final Arg<AtomicChallengeRailTreatment> railTreatmentArg;

  String get title => titleArg.value;

  String get description => descriptionArg.value;

  String get leftText => leftTextArg.value;

  String get rightText => rightTextArg.value;

  AtomicChallengePhase get phase => phaseArg.value;

  double? get fill => fillArg?.value;

  String get dateText => dateTextArg.value;

  String get pointsLogic => pointsLogicArg.value;

  String get ctaLabel => ctaLabelArg.value;

  String? get rules => rulesArg?.value;

  AtomicChallengeRailTreatment get railTreatment => railTreatmentArg.value;

  @override
  List<Arg?> get list => [
    titleArg,
    descriptionArg,
    leftTextArg,
    rightTextArg,
    phaseArg,
    fillArg,
    dateTextArg,
    pointsLogicArg,
    ctaLabelArg,
    rulesArg,
    railTreatmentArg,
  ];
}
