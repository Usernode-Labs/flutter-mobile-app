// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'activity_feed_prototype.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ActivityFeedPrototype, ActivityFeedPrototypeArgs>;
typedef _Scenario = ActivityFeedPrototypeScenario;
typedef _Defaults = ActivityFeedPrototypeDefaults;
typedef _Story = ActivityFeedPrototypeStory;
typedef _Args = ActivityFeedPrototypeArgs;
final ActivityFeedPrototypeComponent =
    Component<ActivityFeedPrototype, ActivityFeedPrototypeArgs>(
      name: meta.name ?? 'ActivityFeedPrototype',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Widgetbook-only prototype for validating the activity feed hierarchy,
pinned attention treatment, and notification-card rhythm inside a root-tab
shell.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ActivityFeedPrototypeScenario =
    Scenario<ActivityFeedPrototype, ActivityFeedPrototypeArgs>;
typedef ActivityFeedPrototypeDefaults =
    Defaults<ActivityFeedPrototype, ActivityFeedPrototypeArgs>;

class ActivityFeedPrototypeStory
    extends Story<ActivityFeedPrototype, ActivityFeedPrototypeArgs> {
  ActivityFeedPrototypeStory({
    super.name,
    super.setup,
    super.modes,
    ActivityFeedPrototypeArgs? args,
    StoryWidgetBuilder<ActivityFeedPrototype, ActivityFeedPrototypeArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? ActivityFeedPrototypeArgs(),
         builder:
             builder ??
             (context, args) => ActivityFeedPrototype(
               key: args.key,
               variant: args.variant,
               appBarSize: args.appBarSize,
               nodeStatus: args.nodeStatus,
               profileLabel: args.profileLabel,
             ),
       );
}

class ActivityFeedPrototypeArgs extends StoryArgs<ActivityFeedPrototype> {
  ActivityFeedPrototypeArgs({
    Arg<Key?>? key,
    Arg<ActivityFeedVariant>? variant,
    Arg<TopStatusAppBarSize>? appBarSize,
    Arg<TopStatusNodeStatus>? nodeStatus,
    Arg<String>? profileLabel,
  }) : this.keyArg = $initArg('key', key, null),
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ActivityFeedVariant>(
           ActivityFeedVariant.attentionFeed,
           values: ActivityFeedVariant.values,
         ),
       )!,
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

  ActivityFeedPrototypeArgs.fixed({
    Key? key,
    ActivityFeedVariant variant = ActivityFeedVariant.attentionFeed,
    TopStatusAppBarSize appBarSize = TopStatusAppBarSize.large,
    TopStatusNodeStatus nodeStatus = TopStatusNodeStatus.synced,
    String profileLabel = '25k pts',
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.variantArg = Arg.fixed(variant),
       this.appBarSizeArg = Arg.fixed(appBarSize),
       this.nodeStatusArg = Arg.fixed(nodeStatus),
       this.profileLabelArg = Arg.fixed(profileLabel);

  final Arg<Key?>? keyArg;

  final Arg<ActivityFeedVariant> variantArg;

  final Arg<TopStatusAppBarSize> appBarSizeArg;

  final Arg<TopStatusNodeStatus> nodeStatusArg;

  final Arg<String> profileLabelArg;

  Key? get key => keyArg?.value;

  ActivityFeedVariant get variant => variantArg.value;

  TopStatusAppBarSize get appBarSize => appBarSizeArg.value;

  TopStatusNodeStatus get nodeStatus => nodeStatusArg.value;

  String get profileLabel => profileLabelArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    variantArg,
    appBarSizeArg,
    nodeStatusArg,
    profileLabelArg,
  ];
}
