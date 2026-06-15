// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'icon_badge.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<IconBadge, IconBadgeArgs>;
typedef _Scenario = IconBadgeScenario;
typedef _Defaults = IconBadgeDefaults;
typedef _Story = IconBadgeStory;
typedef _Args = IconBadgeArgs;
final IconBadgeComponent = Component<IconBadge, IconBadgeArgs>(
  name: meta.name ?? 'IconBadge',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A square container with rounded corners and a centered icon.

Commonly used as a leading element in list rows and metric tiles.
Defaults to the 3-layer model (48px container, 40px surface, 24px icon)
which provides breathing room around the colored surface.

For flush mode (surface fills the container), pass
`size: sizing.iconContainerSmall` (40px outer = 40px surface).

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $CustomColors..$generatedName = 'CustomColors',
  ],
);
typedef IconBadgeScenario = Scenario<IconBadge, IconBadgeArgs>;
typedef IconBadgeDefaults = Defaults<IconBadge, IconBadgeArgs>;

class IconBadgeStory extends Story<IconBadge, IconBadgeArgs> {
  IconBadgeStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<IconBadge, IconBadgeArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => IconBadge(
               key: args.key,
               icon: args.icon,
               size: args.size,
               surfaceSize: args.surfaceSize,
               backgroundColor: args.backgroundColor,
               iconColor: args.iconColor,
               borderRadius: args.borderRadius,
             ),
       );
}

class IconBadgeArgs extends StoryArgs<IconBadge> {
  IconBadgeArgs({
    Arg<Key?>? key,
    required Arg<IconData> icon,
    Arg<double?>? size,
    Arg<double?>? surfaceSize,
    Arg<Color?>? backgroundColor,
    Arg<Color?>? iconColor,
    Arg<BorderRadius?>? borderRadius,
  }) : this.keyArg = $initArg('key', key, null),
       this.iconArg = $initArg('icon', icon, null)!,
       this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!,
       this.surfaceSizeArg = $initArg(
         'surfaceSize',
         surfaceSize,
         NullableDoubleArg(null),
       )!,
       this.backgroundColorArg = $initArg(
         'backgroundColor',
         backgroundColor,
         NullableColorArg(null),
       )!,
       this.iconColorArg = $initArg(
         'iconColor',
         iconColor,
         NullableColorArg(null),
       )!,
       this.borderRadiusArg = $initArg('borderRadius', borderRadius, null);

  IconBadgeArgs.fixed({
    Key? key,
    required IconData icon,
    double? size = null,
    double? surfaceSize = null,
    Color? backgroundColor = null,
    Color? iconColor = null,
    BorderRadius? borderRadius,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.iconArg = Arg.fixed(icon),
       this.sizeArg = size == null ? null : Arg.fixed(size),
       this.surfaceSizeArg = surfaceSize == null
           ? null
           : Arg.fixed(surfaceSize),
       this.backgroundColorArg = backgroundColor == null
           ? null
           : Arg.fixed(backgroundColor),
       this.iconColorArg = iconColor == null ? null : Arg.fixed(iconColor),
       this.borderRadiusArg = borderRadius == null
           ? null
           : Arg.fixed(borderRadius);

  final Arg<Key?>? keyArg;

  final Arg<IconData> iconArg;

  final Arg<double?>? sizeArg;

  final Arg<double?>? surfaceSizeArg;

  final Arg<Color?>? backgroundColorArg;

  final Arg<Color?>? iconColorArg;

  final Arg<BorderRadius?>? borderRadiusArg;

  Key? get key => keyArg?.value;

  IconData get icon => iconArg.value;

  double? get size => sizeArg?.value;

  double? get surfaceSize => surfaceSizeArg?.value;

  Color? get backgroundColor => backgroundColorArg?.value;

  Color? get iconColor => iconColorArg?.value;

  BorderRadius? get borderRadius => borderRadiusArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    iconArg,
    sizeArg,
    surfaceSizeArg,
    backgroundColorArg,
    iconColorArg,
    borderRadiusArg,
  ];
}
