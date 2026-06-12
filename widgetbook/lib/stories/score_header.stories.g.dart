// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'score_header.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ScoreHeader, ScoreHeaderArgs>;
typedef _Scenario = ScoreHeaderScenario;
typedef _Defaults = ScoreHeaderDefaults;
typedef _Story = ScoreHeaderStory;
typedef _Args = ScoreHeaderArgs;
final ScoreHeaderComponent = Component<ScoreHeader, ScoreHeaderArgs>(
  name: meta.name ?? 'ScoreHeader',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A centered score display with circular progress arc, rank label,
countdown timer, and CTA button.

Two variants: [ScoreHeaderVariant.standard] (clean circle) and
[ScoreHeaderVariant.glow] (multi-color box shadows representing
verified membership across the three ecosystem pillars).''',
  stories: [
    $Default..$generatedName = 'Default',
    $Glow..$generatedName = 'Glow',
    $CaughtUp..$generatedName = 'CaughtUp',
  ],
);
typedef ScoreHeaderScenario = Scenario<ScoreHeader, ScoreHeaderArgs>;
typedef ScoreHeaderDefaults = Defaults<ScoreHeader, ScoreHeaderArgs>;

class ScoreHeaderStory extends Story<ScoreHeader, ScoreHeaderArgs> {
  ScoreHeaderStory({
    super.name,
    super.setup,
    super.modes,
    ScoreHeaderArgs? args,
    StoryWidgetBuilder<ScoreHeader, ScoreHeaderArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ScoreHeaderArgs(),
         builder:
             builder ??
             (context, args) => ScoreHeader(
               key: args.key,
               score: args.score,
               scoreLabel: args.scoreLabel,
               rankLabel: args.rankLabel,
               progress: args.progress,
               progressColor: args.progressColor,
               countdownLabel: args.countdownLabel,
               countdownTime: args.countdownTime,
               ctaLabel: args.ctaLabel,
               onCtaTap: args.onCtaTap,
               variant: args.variant,
               glowIntensity: args.glowIntensity,
               technicalGlowIntensity: args.technicalGlowIntensity,
               flashGlowIntensity: args.flashGlowIntensity,
               communityGlowIntensity: args.communityGlowIntensity,
               countdownOpacity: args.countdownOpacity,
               countdownTextMode: args.countdownTextMode,
               showCountdown: args.showCountdown,
               density: args.density,
               footer: args.footer,
             ),
       );
}

class ScoreHeaderArgs extends StoryArgs<ScoreHeader> {
  ScoreHeaderArgs({
    Arg<Key?>? key,
    Arg<String>? score,
    Arg<String>? scoreLabel,
    Arg<String?>? rankLabel,
    Arg<double>? progress,
    Arg<Color?>? progressColor,
    Arg<String?>? countdownLabel,
    Arg<String?>? countdownTime,
    Arg<String?>? ctaLabel,
    Arg<void Function()?>? onCtaTap,
    Arg<ScoreHeaderVariant>? variant,
    Arg<double>? glowIntensity,
    Arg<double?>? technicalGlowIntensity,
    Arg<double?>? flashGlowIntensity,
    Arg<double?>? communityGlowIntensity,
    Arg<double>? countdownOpacity,
    Arg<CountdownTextMode>? countdownTextMode,
    Arg<bool>? showCountdown,
    Arg<ScoreHeaderDensity>? density,
    Arg<Widget?>? footer,
  }) : this.keyArg = $initArg('key', key, null),
       this.scoreArg = $initArg('score', score, StringArg(''))!,
       this.scoreLabelArg = $initArg('scoreLabel', scoreLabel, StringArg(''))!,
       this.rankLabelArg = $initArg(
         'rankLabel',
         rankLabel,
         NullableStringArg(null),
       )!,
       this.progressArg = $initArg('progress', progress, DoubleArg(0.0))!,
       this.progressColorArg = $initArg(
         'progressColor',
         progressColor,
         NullableColorArg(null),
       )!,
       this.countdownLabelArg = $initArg(
         'countdownLabel',
         countdownLabel,
         NullableStringArg('ENDS IN'),
       )!,
       this.countdownTimeArg = $initArg(
         'countdownTime',
         countdownTime,
         NullableStringArg(null),
       )!,
       this.ctaLabelArg = $initArg(
         'ctaLabel',
         ctaLabel,
         NullableStringArg(null),
       )!,
       this.onCtaTapArg = $initArg('onCtaTap', onCtaTap, null),
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ScoreHeaderVariant>(
           ScoreHeaderVariant.standard,
           values: ScoreHeaderVariant.values,
         ),
       )!,
       this.glowIntensityArg = $initArg(
         'glowIntensity',
         glowIntensity,
         DoubleArg(1.0),
       )!,
       this.technicalGlowIntensityArg = $initArg(
         'technicalGlowIntensity',
         technicalGlowIntensity,
         NullableDoubleArg(null),
       )!,
       this.flashGlowIntensityArg = $initArg(
         'flashGlowIntensity',
         flashGlowIntensity,
         NullableDoubleArg(null),
       )!,
       this.communityGlowIntensityArg = $initArg(
         'communityGlowIntensity',
         communityGlowIntensity,
         NullableDoubleArg(null),
       )!,
       this.countdownOpacityArg = $initArg(
         'countdownOpacity',
         countdownOpacity,
         DoubleArg(1.0),
       )!,
       this.countdownTextModeArg = $initArg(
         'countdownTextMode',
         countdownTextMode,
         EnumArg<CountdownTextMode>(
           CountdownTextMode.normal,
           values: CountdownTextMode.values,
         ),
       )!,
       this.showCountdownArg = $initArg(
         'showCountdown',
         showCountdown,
         BoolArg(true),
       )!,
       this.densityArg = $initArg(
         'density',
         density,
         EnumArg<ScoreHeaderDensity>(
           ScoreHeaderDensity.standard,
           values: ScoreHeaderDensity.values,
         ),
       )!,
       this.footerArg = $initArg('footer', footer, null);

  ScoreHeaderArgs.fixed({
    Key? key,
    String score = '',
    String scoreLabel = '',
    String? rankLabel = null,
    double progress = 0.0,
    Color? progressColor = null,
    String? countdownLabel = 'ENDS IN',
    String? countdownTime = null,
    String? ctaLabel = null,
    void Function()? onCtaTap,
    ScoreHeaderVariant variant = ScoreHeaderVariant.standard,
    double glowIntensity = 1.0,
    double? technicalGlowIntensity = null,
    double? flashGlowIntensity = null,
    double? communityGlowIntensity = null,
    double countdownOpacity = 1.0,
    CountdownTextMode countdownTextMode = CountdownTextMode.normal,
    bool showCountdown = true,
    ScoreHeaderDensity density = ScoreHeaderDensity.standard,
    Widget? footer,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.scoreArg = Arg.fixed(score),
       this.scoreLabelArg = Arg.fixed(scoreLabel),
       this.rankLabelArg = rankLabel == null ? null : Arg.fixed(rankLabel),
       this.progressArg = Arg.fixed(progress),
       this.progressColorArg = progressColor == null
           ? null
           : Arg.fixed(progressColor),
       this.countdownLabelArg = countdownLabel == null
           ? null
           : Arg.fixed(countdownLabel),
       this.countdownTimeArg = countdownTime == null
           ? null
           : Arg.fixed(countdownTime),
       this.ctaLabelArg = ctaLabel == null ? null : Arg.fixed(ctaLabel),
       this.onCtaTapArg = onCtaTap == null ? null : Arg.fixed(onCtaTap),
       this.variantArg = Arg.fixed(variant),
       this.glowIntensityArg = Arg.fixed(glowIntensity),
       this.technicalGlowIntensityArg = technicalGlowIntensity == null
           ? null
           : Arg.fixed(technicalGlowIntensity),
       this.flashGlowIntensityArg = flashGlowIntensity == null
           ? null
           : Arg.fixed(flashGlowIntensity),
       this.communityGlowIntensityArg = communityGlowIntensity == null
           ? null
           : Arg.fixed(communityGlowIntensity),
       this.countdownOpacityArg = Arg.fixed(countdownOpacity),
       this.countdownTextModeArg = Arg.fixed(countdownTextMode),
       this.showCountdownArg = Arg.fixed(showCountdown),
       this.densityArg = Arg.fixed(density),
       this.footerArg = footer == null ? null : Arg.fixed(footer);

  final Arg<Key?>? keyArg;

  final Arg<String> scoreArg;

  final Arg<String> scoreLabelArg;

  final Arg<String?>? rankLabelArg;

  final Arg<double> progressArg;

  final Arg<Color?>? progressColorArg;

  final Arg<String?>? countdownLabelArg;

  final Arg<String?>? countdownTimeArg;

  final Arg<String?>? ctaLabelArg;

  final Arg<void Function()?>? onCtaTapArg;

  final Arg<ScoreHeaderVariant> variantArg;

  final Arg<double> glowIntensityArg;

  final Arg<double?>? technicalGlowIntensityArg;

  final Arg<double?>? flashGlowIntensityArg;

  final Arg<double?>? communityGlowIntensityArg;

  final Arg<double> countdownOpacityArg;

  final Arg<CountdownTextMode> countdownTextModeArg;

  final Arg<bool> showCountdownArg;

  final Arg<ScoreHeaderDensity> densityArg;

  final Arg<Widget?>? footerArg;

  Key? get key => keyArg?.value;

  String get score => scoreArg.value;

  String get scoreLabel => scoreLabelArg.value;

  String? get rankLabel => rankLabelArg?.value;

  double get progress => progressArg.value;

  Color? get progressColor => progressColorArg?.value;

  String? get countdownLabel => countdownLabelArg?.value;

  String? get countdownTime => countdownTimeArg?.value;

  String? get ctaLabel => ctaLabelArg?.value;

  void Function()? get onCtaTap => onCtaTapArg?.value;

  ScoreHeaderVariant get variant => variantArg.value;

  double get glowIntensity => glowIntensityArg.value;

  double? get technicalGlowIntensity => technicalGlowIntensityArg?.value;

  double? get flashGlowIntensity => flashGlowIntensityArg?.value;

  double? get communityGlowIntensity => communityGlowIntensityArg?.value;

  double get countdownOpacity => countdownOpacityArg.value;

  CountdownTextMode get countdownTextMode => countdownTextModeArg.value;

  bool get showCountdown => showCountdownArg.value;

  ScoreHeaderDensity get density => densityArg.value;

  Widget? get footer => footerArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    scoreArg,
    scoreLabelArg,
    rankLabelArg,
    progressArg,
    progressColorArg,
    countdownLabelArg,
    countdownTimeArg,
    ctaLabelArg,
    onCtaTapArg,
    variantArg,
    glowIntensityArg,
    technicalGlowIntensityArg,
    flashGlowIntensityArg,
    communityGlowIntensityArg,
    countdownOpacityArg,
    countdownTextModeArg,
    showCountdownArg,
    densityArg,
    footerArg,
  ];
}
