// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'shimmer_block.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ShimmerBlock, ShimmerBlockArgs>;
typedef _Scenario = ShimmerBlockScenario;
typedef _Defaults = ShimmerBlockDefaults;
typedef _Story = ShimmerBlockStory;
typedef _Args = ShimmerBlockArgs;
final ShimmerBlockComponent = Component<ShimmerBlock, ShimmerBlockArgs>(
  name: meta.name ?? 'ShimmerBlock',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A rounded rectangle with a continuous gradient-sweep animation.

The core shimmer primitive for content-first loading. Compose multiple
[ShimmerBlock]s to build skeleton placeholders that match real layout
structure, giving users immediate spatial context during data loading.

When placed inside a [ShimmerHost], shares a single animation controller
with all sibling blocks. Otherwise creates its own controller.

Colors are derived from [ColorScheme] surface container tones:
- **base** = `surfaceContainerHighest`
- **highlight** = `Color.lerp(base, surfaceContainerLowest, t)`
  where *t* = 0.45 in light mode, −0.45 in dark mode (negative lerp
  extrapolates away from the darker anchor, producing a symmetric lift).

Respects [MediaQueryData.disableAnimations] — renders a static block
when reduced motion is preferred.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Large..$generatedName = 'Large',
    $Square..$generatedName = 'Square',
  ],
);
typedef ShimmerBlockScenario = Scenario<ShimmerBlock, ShimmerBlockArgs>;
typedef ShimmerBlockDefaults = Defaults<ShimmerBlock, ShimmerBlockArgs>;

class ShimmerBlockStory extends Story<ShimmerBlock, ShimmerBlockArgs> {
  ShimmerBlockStory({
    super.name,
    super.setup,
    super.modes,
    ShimmerBlockArgs? args,
    StoryWidgetBuilder<ShimmerBlock, ShimmerBlockArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ShimmerBlockArgs(),
         builder:
             builder ??
             (context, args) => ShimmerBlock(
               key: args.key,
               width: args.width,
               height: args.height,
               borderRadius: args.borderRadius,
             ),
       );
}

class ShimmerBlockArgs extends StoryArgs<ShimmerBlock> {
  ShimmerBlockArgs({
    Arg<Key?>? key,
    Arg<double>? width,
    Arg<double>? height,
    Arg<BorderRadius?>? borderRadius,
  }) : this.keyArg = $initArg('key', key, null),
       this.widthArg = $initArg('width', width, DoubleArg(0.0))!,
       this.heightArg = $initArg('height', height, DoubleArg(0.0))!,
       this.borderRadiusArg = $initArg('borderRadius', borderRadius, null);

  ShimmerBlockArgs.fixed({
    Key? key,
    double width = 0.0,
    double height = 0.0,
    BorderRadius? borderRadius,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.widthArg = Arg.fixed(width),
       this.heightArg = Arg.fixed(height),
       this.borderRadiusArg = borderRadius == null
           ? null
           : Arg.fixed(borderRadius);

  final Arg<Key?>? keyArg;

  final Arg<double> widthArg;

  final Arg<double> heightArg;

  final Arg<BorderRadius?>? borderRadiusArg;

  Key? get key => keyArg?.value;

  double get width => widthArg.value;

  double get height => heightArg.value;

  BorderRadius? get borderRadius => borderRadiusArg?.value;

  @override
  List<Arg?> get list => [keyArg, widthArg, heightArg, borderRadiusArg];
}
