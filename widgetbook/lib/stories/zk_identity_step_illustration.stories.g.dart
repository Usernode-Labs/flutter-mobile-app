// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'zk_identity_step_illustration.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ZkIdentityStepIllustration, ZkIdentityStepIllustrationArgs>;
typedef _Scenario = ZkIdentityStepIllustrationScenario;
typedef _Defaults = ZkIdentityStepIllustrationDefaults;
typedef _Story = ZkIdentityStepIllustrationStory;
typedef _Args = ZkIdentityStepIllustrationArgs;
final ZkIdentityStepIllustrationComponent =
    Component<ZkIdentityStepIllustration, ZkIdentityStepIllustrationArgs>(
      name: meta.name ?? 'ZkIdentityStepIllustration',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Animated line-art illustration for each step of the ZK Identity flow.

Ultra-minimal technical drawing style: thin strokes, simple geometry,
generous negative space. Achromatic — resolves colors from [ColorScheme].

[stepIndex] 0–4:
  0 = Check App, 1 = Confirm Scanned, 2 = Ready to Verify,
  3 = Verification, 4 = Result.''',
      stories: [
        $CheckApp..$generatedName = 'CheckApp',
        $ConfirmScanned..$generatedName = 'ConfirmScanned',
        $ReadyToVerify..$generatedName = 'ReadyToVerify',
        $Verification..$generatedName = 'Verification',
        $Result..$generatedName = 'Result',
      ],
    );
typedef ZkIdentityStepIllustrationScenario =
    Scenario<ZkIdentityStepIllustration, ZkIdentityStepIllustrationArgs>;
typedef ZkIdentityStepIllustrationDefaults =
    Defaults<ZkIdentityStepIllustration, ZkIdentityStepIllustrationArgs>;

class ZkIdentityStepIllustrationStory
    extends Story<ZkIdentityStepIllustration, ZkIdentityStepIllustrationArgs> {
  ZkIdentityStepIllustrationStory({
    super.name,
    super.setup,
    super.modes,
    ZkIdentityStepIllustrationArgs? args,
    StoryWidgetBuilder<
      ZkIdentityStepIllustration,
      ZkIdentityStepIllustrationArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? ZkIdentityStepIllustrationArgs(),
         builder:
             builder ??
             (context, args) => ZkIdentityStepIllustration(
               key: args.key,
               stepIndex: args.stepIndex,
             ),
       );
}

class ZkIdentityStepIllustrationArgs
    extends StoryArgs<ZkIdentityStepIllustration> {
  ZkIdentityStepIllustrationArgs({Arg<Key?>? key, Arg<int>? stepIndex})
    : this.keyArg = $initArg('key', key, null),
      this.stepIndexArg = $initArg('stepIndex', stepIndex, IntArg(0))!;

  ZkIdentityStepIllustrationArgs.fixed({Key? key, int stepIndex = 0})
    : this.keyArg = key == null ? null : Arg.fixed(key),
      this.stepIndexArg = Arg.fixed(stepIndex);

  final Arg<Key?>? keyArg;

  final Arg<int> stepIndexArg;

  Key? get key => keyArg?.value;

  int get stepIndex => stepIndexArg.value;

  @override
  List<Arg?> get list => [keyArg, stepIndexArg];
}
