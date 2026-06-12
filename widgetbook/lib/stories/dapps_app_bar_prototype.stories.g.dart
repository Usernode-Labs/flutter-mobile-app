// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dapps_app_bar_prototype.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DappsAppBarPrototype, DappsAppBarPrototypeArgs>;
typedef _Scenario = DappsAppBarPrototypeScenario;
typedef _Defaults = DappsAppBarPrototypeDefaults;
typedef _Story = DappsAppBarPrototypeStory;
typedef _Args = DappsAppBarPrototypeArgs;
final DappsAppBarPrototypeComponent =
    Component<DappsAppBarPrototype, DappsAppBarPrototypeArgs>(
      name: meta.name ?? 'DappsAppBarPrototype',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Stateless Widgetbook-only prototype for aligning the dApps root with the
new top status app bar pattern.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef DappsAppBarPrototypeScenario =
    Scenario<DappsAppBarPrototype, DappsAppBarPrototypeArgs>;
typedef DappsAppBarPrototypeDefaults =
    Defaults<DappsAppBarPrototype, DappsAppBarPrototypeArgs>;

class DappsAppBarPrototypeStory
    extends Story<DappsAppBarPrototype, DappsAppBarPrototypeArgs> {
  DappsAppBarPrototypeStory({
    super.name,
    super.setup,
    super.modes,
    DappsAppBarPrototypeArgs? args,
    StoryWidgetBuilder<DappsAppBarPrototype, DappsAppBarPrototypeArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? DappsAppBarPrototypeArgs(),
         builder:
             builder ??
             (context, args) => DappsAppBarPrototype(
               key: args.key,
               appBarSize: args.appBarSize,
               nodeStatus: args.nodeStatus,
               profileLabel: args.profileLabel,
             ),
       );
}

class DappsAppBarPrototypeArgs extends StoryArgs<DappsAppBarPrototype> {
  DappsAppBarPrototypeArgs({
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

  DappsAppBarPrototypeArgs.fixed({
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
