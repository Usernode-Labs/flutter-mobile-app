// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'atomic_challenge_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<AtomicChallengeCard, AtomicChallengeCardInputArgs>;
typedef _Scenario = AtomicChallengeCardScenario;
typedef _Defaults = AtomicChallengeCardDefaults;
typedef _Story = AtomicChallengeCardStory;
typedef _Args = AtomicChallengeCardInputArgs;
final AtomicChallengeCardComponent =
    Component<AtomicChallengeCard, AtomicChallengeCardInputArgs>(
      name: meta.name ?? 'AtomicChallengeCard',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Widgetbook-only exploration of the atomic challenge rail model.

Each card represents exactly one earning mechanic and one verification path.
Pending labels are reserved for the finalization gap after the user action
is complete.''',
      stories: [
        $AtomicRail..$generatedName = 'AtomicRail',
        $BackgroundBlockProduction
          ..$generatedName = 'BackgroundBlockProduction',
      ],
    );
typedef AtomicChallengeCardScenario =
    Scenario<AtomicChallengeCard, AtomicChallengeCardInputArgs>;
typedef AtomicChallengeCardDefaults =
    Defaults<AtomicChallengeCard, AtomicChallengeCardInputArgs>;

class AtomicChallengeCardStory
    extends Story<AtomicChallengeCard, AtomicChallengeCardInputArgs> {
  AtomicChallengeCardStory({
    super.name,
    SetupBuilder<AtomicChallengeCard, AtomicChallengeCardInputArgs>? setup,
    super.modes,
    AtomicChallengeCardInputArgs? args,
    StoryWidgetBuilder<AtomicChallengeCard, AtomicChallengeCardInputArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? AtomicChallengeCardInputArgs(),
         builder: builder ?? defaults.builder!,
         setup: setup ?? defaults.setup!,
       );
}

class AtomicChallengeCardInputArgs extends StoryArgs<AtomicChallengeCard> {
  AtomicChallengeCardInputArgs({
    Arg<String>? title,
    Arg<String>? leftText,
    Arg<String>? rightText,
    Arg<AtomicChallengePhase>? phase,
    Arg<double?>? fill,
    Arg<double>? cardWidth,
    Arg<bool>? featured,
    Arg<AtomicChallengeRailTreatment>? railTreatment,
  }) : this.titleArg = $initArg('title', title, StringArg('Give kudos'))!,
       this.leftTextArg = $initArg('leftText', leftText, StringArg('2 / 5'))!,
       this.rightTextArg = $initArg(
         'rightText',
         rightText,
         StringArg('400 / 1,500 pts'),
       )!,
       this.phaseArg = $initArg(
         'phase',
         phase,
         EnumArg<AtomicChallengePhase>(
           AtomicChallengePhase.inProgress,
           values: AtomicChallengePhase.values,
         ),
       )!,
       this.fillArg = $initArg('fill', fill, NullableDoubleArg(0.4))!,
       this.cardWidthArg = $initArg('cardWidth', cardWidth, DoubleArg(358))!,
       this.featuredArg = $initArg('featured', featured, BoolArg(false))!,
       this.railTreatmentArg = $initArg(
         'railTreatment',
         railTreatment,
         EnumArg<AtomicChallengeRailTreatment>(
           AtomicChallengeRailTreatment.standard,
           values: AtomicChallengeRailTreatment.values,
         ),
       )!;

  AtomicChallengeCardInputArgs.fixed({
    String title = 'Give kudos',
    String leftText = '2 / 5',
    String rightText = '400 / 1,500 pts',
    AtomicChallengePhase phase = AtomicChallengePhase.inProgress,
    double? fill = 0.4,
    double cardWidth = 358,
    bool featured = false,
    AtomicChallengeRailTreatment railTreatment =
        AtomicChallengeRailTreatment.standard,
  }) : this.titleArg = Arg.fixed(title),
       this.leftTextArg = Arg.fixed(leftText),
       this.rightTextArg = Arg.fixed(rightText),
       this.phaseArg = Arg.fixed(phase),
       this.fillArg = fill == null ? null : Arg.fixed(fill),
       this.cardWidthArg = Arg.fixed(cardWidth),
       this.featuredArg = Arg.fixed(featured),
       this.railTreatmentArg = Arg.fixed(railTreatment);

  final Arg<String> titleArg;

  final Arg<String> leftTextArg;

  final Arg<String> rightTextArg;

  final Arg<AtomicChallengePhase> phaseArg;

  final Arg<double?>? fillArg;

  final Arg<double> cardWidthArg;

  final Arg<bool> featuredArg;

  final Arg<AtomicChallengeRailTreatment> railTreatmentArg;

  String get title => titleArg.value;

  String get leftText => leftTextArg.value;

  String get rightText => rightTextArg.value;

  AtomicChallengePhase get phase => phaseArg.value;

  double? get fill => fillArg?.value;

  double get cardWidth => cardWidthArg.value;

  bool get featured => featuredArg.value;

  AtomicChallengeRailTreatment get railTreatment => railTreatmentArg.value;

  @override
  List<Arg?> get list => [
    titleArg,
    leftTextArg,
    rightTextArg,
    phaseArg,
    fillArg,
    cardWidthArg,
    featuredArg,
    railTreatmentArg,
  ];
}
