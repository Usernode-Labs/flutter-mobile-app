// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'active_challenge_bands.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ActiveChallengeBands, ActiveChallengeBandsArgs>;
typedef _Scenario = ActiveChallengeBandsScenario;
typedef _Defaults = ActiveChallengeBandsDefaults;
typedef _Story = ActiveChallengeBandsStory;
typedef _Args = ActiveChallengeBandsArgs;
final ActiveChallengeBandsComponent =
    Component<ActiveChallengeBands, ActiveChallengeBandsArgs>(
      name: meta.name ?? 'ActiveChallengeBands',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Widgetbook-only preview of the active Fair Rewards challenge surface.

Deadlines live at the band layer; atomic cards stay focused on progress and
reward state.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ActiveChallengeBandsScenario =
    Scenario<ActiveChallengeBands, ActiveChallengeBandsArgs>;
typedef ActiveChallengeBandsDefaults =
    Defaults<ActiveChallengeBands, ActiveChallengeBandsArgs>;

class ActiveChallengeBandsStory
    extends Story<ActiveChallengeBands, ActiveChallengeBandsArgs> {
  ActiveChallengeBandsStory({
    super.name,
    super.setup,
    super.modes,
    ActiveChallengeBandsArgs? args,
    StoryWidgetBuilder<ActiveChallengeBands, ActiveChallengeBandsArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ActiveChallengeBandsArgs(),
         builder:
             builder ??
             (context, args) => ActiveChallengeBands(
               key: args.key,
               appBarSize: args.appBarSize,
               nodeStatus: args.nodeStatus,
               profileLabel: args.profileLabel,
             ),
       );
}

class ActiveChallengeBandsArgs extends StoryArgs<ActiveChallengeBands> {
  ActiveChallengeBandsArgs({
    Arg<Key?>? key,
    Arg<TopStatusAppBarSize>? appBarSize,
    Arg<TopStatusNodeStatus>? nodeStatus,
    Arg<String>? profileLabel,
  }) : this.keyArg = $initArg('key', key, null),
       this.appBarSizeArg = $initArg(
         'appBarSize',
         appBarSize,
         EnumArg<TopStatusAppBarSize>(
           TopStatusAppBarSize.large,
           values: TopStatusAppBarSize.values,
         ),
       )!,
       this.nodeStatusArg = $initArg(
         'nodeStatus',
         nodeStatus,
         EnumArg<TopStatusNodeStatus>(
           TopStatusNodeStatus.synced,
           values: TopStatusNodeStatus.values,
         ),
       )!,
       this.profileLabelArg = $initArg(
         'profileLabel',
         profileLabel,
         StringArg('25k pts'),
       )!;

  ActiveChallengeBandsArgs.fixed({
    Key? key,
    TopStatusAppBarSize appBarSize = TopStatusAppBarSize.large,
    TopStatusNodeStatus nodeStatus = TopStatusNodeStatus.synced,
    String profileLabel = '25k pts',
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.appBarSizeArg = Arg.fixed(appBarSize),
       this.nodeStatusArg = Arg.fixed(nodeStatus),
       this.profileLabelArg = Arg.fixed(profileLabel);

  final Arg<Key?>? keyArg;

  final Arg<TopStatusAppBarSize> appBarSizeArg;

  final Arg<TopStatusNodeStatus> nodeStatusArg;

  final Arg<String> profileLabelArg;

  Key? get key => keyArg?.value;

  TopStatusAppBarSize get appBarSize => appBarSizeArg.value;

  TopStatusNodeStatus get nodeStatus => nodeStatusArg.value;

  String get profileLabel => profileLabelArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    appBarSizeArg,
    nodeStatusArg,
    profileLabelArg,
  ];
}
