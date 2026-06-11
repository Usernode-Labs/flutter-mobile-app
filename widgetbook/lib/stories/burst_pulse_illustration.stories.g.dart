// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'burst_pulse_illustration.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component
    = Component<BurstPulseIllustration, BurstPulseIllustrationArgs>;
typedef _Scenario = BurstPulseIllustrationScenario;
typedef _Defaults = BurstPulseIllustrationDefaults;
typedef _Story = BurstPulseIllustrationStory;
typedef _Args = BurstPulseIllustrationArgs;
final BurstPulseIllustrationComponent =
    Component<BurstPulseIllustration, BurstPulseIllustrationArgs>(
  name: meta.name ?? 'BurstPulseIllustration',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''Expanding concentric rings animation for the burst transactions screen.

Each entry in [rings] emits a ring from the center that expands and fades
over 2.5 seconds. Succeeded rings are solid; failed rings are dashed.

Presentation-only — the screen builds [rings] from provider state.''',
  stories: [
    $Default..$generatedName = 'Default',
    $AllSucceeded..$generatedName = 'AllSucceeded',
    $Inactive..$generatedName = 'Inactive',
  ],
);
typedef BurstPulseIllustrationScenario
    = Scenario<BurstPulseIllustration, BurstPulseIllustrationArgs>;
typedef BurstPulseIllustrationDefaults
    = Defaults<BurstPulseIllustration, BurstPulseIllustrationArgs>;

class BurstPulseIllustrationStory
    extends Story<BurstPulseIllustration, BurstPulseIllustrationArgs> {
  BurstPulseIllustrationStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<BurstPulseIllustration, BurstPulseIllustrationArgs>?
        builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => BurstPulseIllustration(
                    key: args.key,
                    rings: args.rings,
                    active: args.active,
                  ),
        );
}

class BurstPulseIllustrationArgs extends StoryArgs<BurstPulseIllustration> {
  BurstPulseIllustrationArgs({
    Arg<Key?>? key,
    required Arg<List<BurstRingOutcome>> rings,
    Arg<bool>? active,
  })  : this.keyArg = $initArg('key', key, null),
        this.ringsArg = $initArg('rings', rings, null)!,
        this.activeArg = $initArg('active', active, BoolArg(true))!;

  BurstPulseIllustrationArgs.fixed({
    Key? key,
    required List<BurstRingOutcome> rings,
    bool active = true,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.ringsArg = Arg.fixed(rings),
        this.activeArg = Arg.fixed(active);

  final Arg<Key?>? keyArg;

  final Arg<List<BurstRingOutcome>> ringsArg;

  final Arg<bool> activeArg;

  Key? get key => keyArg?.value;

  List<BurstRingOutcome> get rings => ringsArg.value;

  bool get active => activeArg.value;

  @override
  List<Arg?> get list => [keyArg, ringsArg, activeArg];
}
