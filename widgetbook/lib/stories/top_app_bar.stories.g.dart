// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'top_app_bar.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TopAppBar, TopAppBarArgs>;
typedef _Scenario = TopAppBarScenario;
typedef _Defaults = TopAppBarDefaults;
typedef _Story = TopAppBarStory;
typedef _Args = TopAppBarArgs;
final TopAppBarComponent = Component<TopAppBar, TopAppBarArgs>(
  name: meta.name ?? 'TopAppBar',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A sliver-based top app bar with two size variants.

**Small**: standard 56px M3 top app bar with leading, title, and trailing
actions.

**Large**: expanded header with optional image, display title, and subtitle
that collapses to the small layout on scroll. The expanded content fades out
and the title transitions from [TextTheme.displaySmall] to
[TextTheme.titleLarge].

Must be placed inside a [CustomScrollView] or [NestedScrollView].
Does not implement [PreferredSizeWidget].''',
  stories: [$Small..$generatedName = 'Small', $Large..$generatedName = 'Large'],
);
typedef TopAppBarScenario = Scenario<TopAppBar, TopAppBarArgs>;
typedef TopAppBarDefaults = Defaults<TopAppBar, TopAppBarArgs>;

class TopAppBarStory extends Story<TopAppBar, TopAppBarArgs> {
  TopAppBarStory({
    super.name,
    super.setup,
    super.modes,
    TopAppBarArgs? args,
    StoryWidgetBuilder<TopAppBar, TopAppBarArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? TopAppBarArgs(),
         builder:
             builder ??
             (context, args) => TopAppBar(
               key: args.key,
               title: args.title,
               size: args.size,
               leading: args.leading,
               onLeadingTap: args.onLeadingTap,
               actions: args.actions,
               image: args.image,
               subtitle: args.subtitle,
               backgroundColor: args.backgroundColor,
             ),
       );
}

class TopAppBarArgs extends StoryArgs<TopAppBar> {
  TopAppBarArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<TopAppBarSize>? size,
    Arg<Widget?>? leading,
    Arg<void Function()?>? onLeadingTap,
    Arg<List<Widget>?>? actions,
    Arg<Widget?>? image,
    Arg<String?>? subtitle,
    Arg<Color?>? backgroundColor,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<TopAppBarSize>(
           TopAppBarSize.small,
           values: TopAppBarSize.values,
         ),
       )!,
       this.leadingArg = $initArg('leading', leading, null),
       this.onLeadingTapArg = $initArg('onLeadingTap', onLeadingTap, null),
       this.actionsArg = $initArg('actions', actions, null),
       this.imageArg = $initArg('image', image, null),
       this.subtitleArg = $initArg(
         'subtitle',
         subtitle,
         NullableStringArg(null),
       )!,
       this.backgroundColorArg = $initArg(
         'backgroundColor',
         backgroundColor,
         NullableColorArg(null),
       )!;

  TopAppBarArgs.fixed({
    Key? key,
    String title = '',
    TopAppBarSize size = TopAppBarSize.small,
    Widget? leading,
    void Function()? onLeadingTap,
    List<Widget>? actions,
    Widget? image,
    String? subtitle = null,
    Color? backgroundColor = null,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.sizeArg = Arg.fixed(size),
       this.leadingArg = leading == null ? null : Arg.fixed(leading),
       this.onLeadingTapArg = onLeadingTap == null
           ? null
           : Arg.fixed(onLeadingTap),
       this.actionsArg = actions == null ? null : Arg.fixed(actions),
       this.imageArg = image == null ? null : Arg.fixed(image),
       this.subtitleArg = subtitle == null ? null : Arg.fixed(subtitle),
       this.backgroundColorArg = backgroundColor == null
           ? null
           : Arg.fixed(backgroundColor);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<TopAppBarSize> sizeArg;

  final Arg<Widget?>? leadingArg;

  final Arg<void Function()?>? onLeadingTapArg;

  final Arg<List<Widget>?>? actionsArg;

  final Arg<Widget?>? imageArg;

  final Arg<String?>? subtitleArg;

  final Arg<Color?>? backgroundColorArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  TopAppBarSize get size => sizeArg.value;

  Widget? get leading => leadingArg?.value;

  void Function()? get onLeadingTap => onLeadingTapArg?.value;

  List<Widget>? get actions => actionsArg?.value;

  Widget? get image => imageArg?.value;

  String? get subtitle => subtitleArg?.value;

  Color? get backgroundColor => backgroundColorArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    sizeArg,
    leadingArg,
    onLeadingTapArg,
    actionsArg,
    imageArg,
    subtitleArg,
    backgroundColorArg,
  ];
}
