// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'zk_identity_flow_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ZkIdentityFlowPage, ZkIdentityFlowPageArgs>;
typedef _Scenario = ZkIdentityFlowPageScenario;
typedef _Defaults = ZkIdentityFlowPageDefaults;
typedef _Story = ZkIdentityFlowPageStory;
typedef _Args = ZkIdentityFlowPageArgs;
final ZkIdentityFlowPageComponent =
    Component<ZkIdentityFlowPage, ZkIdentityFlowPageArgs>(
      name: meta.name ?? 'ZkIdentityFlowPage',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $StepOne..$generatedName = 'StepOne',
        $StepTwoInProgress..$generatedName = 'StepTwoInProgress',
        $Completed..$generatedName = 'Completed',
        $Failed..$generatedName = 'Failed',
      ],
    );
typedef ZkIdentityFlowPageScenario =
    Scenario<ZkIdentityFlowPage, ZkIdentityFlowPageArgs>;
typedef ZkIdentityFlowPageDefaults =
    Defaults<ZkIdentityFlowPage, ZkIdentityFlowPageArgs>;

class ZkIdentityFlowPageStory
    extends Story<ZkIdentityFlowPage, ZkIdentityFlowPageArgs> {
  ZkIdentityFlowPageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ZkIdentityFlowPage, ZkIdentityFlowPageArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => ZkIdentityFlowPage(
               key: args.key,
               steps: args.steps,
               currentStepIndex: args.currentStepIndex,
               centerActiveContent: args.centerActiveContent,
               activeStepContent: args.activeStepContent,
               bottomAction: args.bottomAction,
               onBack: args.onBack,
             ),
       );
}

class ZkIdentityFlowPageArgs extends StoryArgs<ZkIdentityFlowPage> {
  ZkIdentityFlowPageArgs({
    Arg<Key?>? key,
    required Arg<List<ZkIdentityStepData>> steps,
    Arg<int>? currentStepIndex,
    Arg<bool>? centerActiveContent,
    Arg<Widget?>? activeStepContent,
    Arg<Widget?>? bottomAction,
    Arg<void Function()?>? onBack,
  }) : this.keyArg = $initArg('key', key, null),
       this.stepsArg = $initArg('steps', steps, null)!,
       this.currentStepIndexArg = $initArg(
         'currentStepIndex',
         currentStepIndex,
         IntArg(0),
       )!,
       this.centerActiveContentArg = $initArg(
         'centerActiveContent',
         centerActiveContent,
         BoolArg(false),
       )!,
       this.activeStepContentArg = $initArg(
         'activeStepContent',
         activeStepContent,
         null,
       ),
       this.bottomActionArg = $initArg('bottomAction', bottomAction, null),
       this.onBackArg = $initArg('onBack', onBack, null);

  ZkIdentityFlowPageArgs.fixed({
    Key? key,
    required List<ZkIdentityStepData> steps,
    int currentStepIndex = 0,
    bool centerActiveContent = false,
    Widget? activeStepContent,
    Widget? bottomAction,
    void Function()? onBack,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.stepsArg = Arg.fixed(steps),
       this.currentStepIndexArg = Arg.fixed(currentStepIndex),
       this.centerActiveContentArg = Arg.fixed(centerActiveContent),
       this.activeStepContentArg = activeStepContent == null
           ? null
           : Arg.fixed(activeStepContent),
       this.bottomActionArg = bottomAction == null
           ? null
           : Arg.fixed(bottomAction),
       this.onBackArg = onBack == null ? null : Arg.fixed(onBack);

  final Arg<Key?>? keyArg;

  final Arg<List<ZkIdentityStepData>> stepsArg;

  final Arg<int> currentStepIndexArg;

  final Arg<bool> centerActiveContentArg;

  final Arg<Widget?>? activeStepContentArg;

  final Arg<Widget?>? bottomActionArg;

  final Arg<void Function()?>? onBackArg;

  Key? get key => keyArg?.value;

  List<ZkIdentityStepData> get steps => stepsArg.value;

  int get currentStepIndex => currentStepIndexArg.value;

  bool get centerActiveContent => centerActiveContentArg.value;

  Widget? get activeStepContent => activeStepContentArg?.value;

  Widget? get bottomAction => bottomActionArg?.value;

  void Function()? get onBack => onBackArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    stepsArg,
    currentStepIndexArg,
    centerActiveContentArg,
    activeStepContentArg,
    bottomActionArg,
    onBackArg,
  ];
}
