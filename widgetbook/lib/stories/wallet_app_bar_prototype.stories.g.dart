// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'wallet_app_bar_prototype.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<WalletAppBarPrototype, WalletAppBarPrototypeArgs>;
typedef _Scenario = WalletAppBarPrototypeScenario;
typedef _Defaults = WalletAppBarPrototypeDefaults;
typedef _Story = WalletAppBarPrototypeStory;
typedef _Args = WalletAppBarPrototypeArgs;
final WalletAppBarPrototypeComponent =
    Component<WalletAppBarPrototype, WalletAppBarPrototypeArgs>(
      name: meta.name ?? 'WalletAppBarPrototype',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Widgetbook-only prototype for aligning the wallet root with the new top
status app bar pattern.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef WalletAppBarPrototypeScenario =
    Scenario<WalletAppBarPrototype, WalletAppBarPrototypeArgs>;
typedef WalletAppBarPrototypeDefaults =
    Defaults<WalletAppBarPrototype, WalletAppBarPrototypeArgs>;

class WalletAppBarPrototypeStory
    extends Story<WalletAppBarPrototype, WalletAppBarPrototypeArgs> {
  WalletAppBarPrototypeStory({
    super.name,
    super.setup,
    super.modes,
    WalletAppBarPrototypeArgs? args,
    StoryWidgetBuilder<WalletAppBarPrototype, WalletAppBarPrototypeArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? WalletAppBarPrototypeArgs(),
         builder:
             builder ??
             (context, args) => WalletAppBarPrototype(
               key: args.key,
               appBarSize: args.appBarSize,
               nodeStatus: args.nodeStatus,
               profileLabel: args.profileLabel,
             ),
       );
}

class WalletAppBarPrototypeArgs extends StoryArgs<WalletAppBarPrototype> {
  WalletAppBarPrototypeArgs({
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

  WalletAppBarPrototypeArgs.fixed({
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
