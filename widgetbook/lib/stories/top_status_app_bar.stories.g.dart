// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'top_status_app_bar.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs>;
typedef _Scenario = TopStatusAppBarPreviewScenario;
typedef _Defaults = TopStatusAppBarPreviewDefaults;
typedef _Story = TopStatusAppBarPreviewStory;
typedef _Args = TopStatusAppBarPreviewArgs;
final TopStatusAppBarPreviewComponent =
    Component<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs>(
      name: meta.name ?? 'TopStatusAppBarPreview',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $Large..$generatedName = 'Large',
        $LargeCollapsed..$generatedName = 'LargeCollapsed',
        $Compact..$generatedName = 'Compact',
      ],
    );
typedef TopStatusAppBarPreviewScenario =
    Scenario<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs>;
typedef TopStatusAppBarPreviewDefaults =
    Defaults<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs>;

class TopStatusAppBarPreviewStory
    extends Story<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs> {
  TopStatusAppBarPreviewStory({
    super.name,
    super.setup,
    super.modes,
    TopStatusAppBarPreviewArgs? args,
    StoryWidgetBuilder<TopStatusAppBarPreview, TopStatusAppBarPreviewArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? TopStatusAppBarPreviewArgs(),
         builder:
             builder ??
             (context, args) => TopStatusAppBarPreview(
               key: args.key,
               title: args.title,
               size: args.size,
               onProfilePressed: args.onProfilePressed,
               onNodePressed: args.onNodePressed,
               profileLabel: args.profileLabel,
               nodeStatus: args.nodeStatus,
               backgroundColor: args.backgroundColor,
               forceTransparent: args.forceTransparent,
             ),
       );
}

class TopStatusAppBarPreviewArgs extends StoryArgs<TopStatusAppBarPreview> {
  TopStatusAppBarPreviewArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<TopStatusAppBarSize>? size,
    Arg<void Function()?>? onProfilePressed,
    Arg<void Function()?>? onNodePressed,
    Arg<String?>? profileLabel,
    Arg<TopStatusNodeStatus>? nodeStatus,
    Arg<Color?>? backgroundColor,
    Arg<bool>? forceTransparent,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<TopStatusAppBarSize>(
           TopStatusAppBarSize.large,
           values: TopStatusAppBarSize.values,
         ),
       )!,
       this.onProfilePressedArg = $initArg(
         'onProfilePressed',
         onProfilePressed,
         null,
       ),
       this.onNodePressedArg = $initArg('onNodePressed', onNodePressed, null),
       this.profileLabelArg = $initArg(
         'profileLabel',
         profileLabel,
         NullableStringArg('Profile'),
       )!,
       this.nodeStatusArg = $initArg(
         'nodeStatus',
         nodeStatus,
         EnumArg<TopStatusNodeStatus>(
           TopStatusNodeStatus.synced,
           values: TopStatusNodeStatus.values,
         ),
       )!,
       this.backgroundColorArg = $initArg(
         'backgroundColor',
         backgroundColor,
         NullableColorArg(null),
       )!,
       this.forceTransparentArg = $initArg(
         'forceTransparent',
         forceTransparent,
         BoolArg(false),
       )!;

  TopStatusAppBarPreviewArgs.fixed({
    Key? key,
    String title = '',
    TopStatusAppBarSize size = TopStatusAppBarSize.large,
    void Function()? onProfilePressed,
    void Function()? onNodePressed,
    String? profileLabel = 'Profile',
    TopStatusNodeStatus nodeStatus = TopStatusNodeStatus.synced,
    Color? backgroundColor = null,
    bool forceTransparent = false,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.sizeArg = Arg.fixed(size),
       this.onProfilePressedArg = onProfilePressed == null
           ? null
           : Arg.fixed(onProfilePressed),
       this.onNodePressedArg = onNodePressed == null
           ? null
           : Arg.fixed(onNodePressed),
       this.profileLabelArg = profileLabel == null
           ? null
           : Arg.fixed(profileLabel),
       this.nodeStatusArg = Arg.fixed(nodeStatus),
       this.backgroundColorArg = backgroundColor == null
           ? null
           : Arg.fixed(backgroundColor),
       this.forceTransparentArg = Arg.fixed(forceTransparent);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<TopStatusAppBarSize> sizeArg;

  final Arg<void Function()?>? onProfilePressedArg;

  final Arg<void Function()?>? onNodePressedArg;

  final Arg<String?>? profileLabelArg;

  final Arg<TopStatusNodeStatus> nodeStatusArg;

  final Arg<Color?>? backgroundColorArg;

  final Arg<bool> forceTransparentArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  TopStatusAppBarSize get size => sizeArg.value;

  void Function()? get onProfilePressed => onProfilePressedArg?.value;

  void Function()? get onNodePressed => onNodePressedArg?.value;

  String? get profileLabel => profileLabelArg?.value;

  TopStatusNodeStatus get nodeStatus => nodeStatusArg.value;

  Color? get backgroundColor => backgroundColorArg?.value;

  bool get forceTransparent => forceTransparentArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    sizeArg,
    onProfilePressedArg,
    onNodePressedArg,
    profileLabelArg,
    nodeStatusArg,
    backgroundColorArg,
    forceTransparentArg,
  ];
}
