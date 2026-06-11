// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dropdown_chain.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DropdownChain, DropdownChainArgs>;
typedef _Scenario = DropdownChainScenario;
typedef _Defaults = DropdownChainDefaults;
typedef _Story = DropdownChainStory;
typedef _Args = DropdownChainArgs;
final DropdownChainComponent = Component<DropdownChain, DropdownChainArgs>(
  name: meta.name ?? 'DropdownChain',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A horizontal row of [DropdownChip]s separated by chevron icons.

The last chip expands to fill remaining width; all preceding chips
shrink-wrap. Chevron-forward icons indicate hierarchical narrowing
(e.g. Season > Category).

Composes [DropdownChip] — presentation-only, all state via constructor.''',
  stories: [
    $Default..$generatedName = 'Default',
    $ThreeItems..$generatedName = 'ThreeItems',
  ],
);
typedef DropdownChainScenario = Scenario<DropdownChain, DropdownChainArgs>;
typedef DropdownChainDefaults = Defaults<DropdownChain, DropdownChainArgs>;

class DropdownChainStory extends Story<DropdownChain, DropdownChainArgs> {
  DropdownChainStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<DropdownChain, DropdownChainArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => DropdownChain(
                    key: args.key,
                    items: args.items,
                    variant: args.variant,
                    size: args.size,
                  ),
        );
}

class DropdownChainArgs extends StoryArgs<DropdownChain> {
  DropdownChainArgs({
    Arg<Key?>? key,
    required Arg<List<DropdownChainItem>> items,
    Arg<ChipVariant>? variant,
    Arg<ChipSize>? size,
  })  : this.keyArg = $initArg('key', key, null),
        this.itemsArg = $initArg('items', items, null)!,
        this.variantArg = $initArg(
          'variant',
          variant,
          EnumArg<ChipVariant>(ChipVariant.surface, values: ChipVariant.values),
        )!,
        this.sizeArg = $initArg(
          'size',
          size,
          EnumArg<ChipSize>(ChipSize.regular, values: ChipSize.values),
        )!;

  DropdownChainArgs.fixed({
    Key? key,
    required List<DropdownChainItem> items,
    ChipVariant variant = ChipVariant.surface,
    ChipSize size = ChipSize.regular,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.itemsArg = Arg.fixed(items),
        this.variantArg = Arg.fixed(variant),
        this.sizeArg = Arg.fixed(size);

  final Arg<Key?>? keyArg;

  final Arg<List<DropdownChainItem>> itemsArg;

  final Arg<ChipVariant> variantArg;

  final Arg<ChipSize> sizeArg;

  Key? get key => keyArg?.value;

  List<DropdownChainItem> get items => itemsArg.value;

  ChipVariant get variant => variantArg.value;

  ChipSize get size => sizeArg.value;

  @override
  List<Arg?> get list => [keyArg, itemsArg, variantArg, sizeArg];
}
