// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dropdown_chip.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DropdownChip, DropdownChipArgs>;
typedef _Scenario = DropdownChipScenario;
typedef _Defaults = DropdownChipDefaults;
typedef _Story = DropdownChipStory;
typedef _Args = DropdownChipArgs;
final DropdownChipComponent = Component<DropdownChip, DropdownChipArgs>(
  name: meta.name ?? 'DropdownChip',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A lean filter chip with a dropdown chevron.

Used for filter rows where the user taps to select from options via a
bottom sheet or menu. Supports three visual variants ([ChipVariant]) and
two sizes ([ChipSize]), mirroring the [Button] widget's organization.

Presentation-only — the screen manages selection state and passes the
current label.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Surface..$generatedName = 'Surface',
    $Disabled..$generatedName = 'Disabled',
  ],
);
typedef DropdownChipScenario = Scenario<DropdownChip, DropdownChipArgs>;
typedef DropdownChipDefaults = Defaults<DropdownChip, DropdownChipArgs>;

class DropdownChipStory extends Story<DropdownChip, DropdownChipArgs> {
  DropdownChipStory({
    super.name,
    super.setup,
    super.modes,
    DropdownChipArgs? args,
    StoryWidgetBuilder<DropdownChip, DropdownChipArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? DropdownChipArgs(),
         builder:
             builder ??
             (context, args) => DropdownChip(
               key: args.key,
               label: args.label,
               onTap: args.onTap,
               expanded: args.expanded,
               variant: args.variant,
               size: args.size,
               enabled: args.enabled,
               borderColor: args.borderColor,
               selected: args.selected,
             ),
       );
}

class DropdownChipArgs extends StoryArgs<DropdownChip> {
  DropdownChipArgs({
    Arg<Key?>? key,
    Arg<String>? label,
    Arg<void Function()?>? onTap,
    Arg<bool>? expanded,
    Arg<ChipVariant>? variant,
    Arg<ChipSize>? size,
    Arg<bool>? enabled,
    Arg<Color?>? borderColor,
    Arg<bool?>? selected,
  }) : this.keyArg = $initArg('key', key, null),
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.onTapArg = $initArg('onTap', onTap, null),
       this.expandedArg = $initArg('expanded', expanded, BoolArg(false))!,
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ChipVariant>(ChipVariant.outlined, values: ChipVariant.values),
       )!,
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<ChipSize>(ChipSize.regular, values: ChipSize.values),
       )!,
       this.enabledArg = $initArg('enabled', enabled, BoolArg(true))!,
       this.borderColorArg = $initArg(
         'borderColor',
         borderColor,
         NullableColorArg(null),
       )!,
       this.selectedArg = $initArg(
         'selected',
         selected,
         NullableBoolArg(null),
       )!;

  DropdownChipArgs.fixed({
    Key? key,
    String label = '',
    void Function()? onTap,
    bool expanded = false,
    ChipVariant variant = ChipVariant.outlined,
    ChipSize size = ChipSize.regular,
    bool enabled = true,
    Color? borderColor = null,
    bool? selected = null,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.labelArg = Arg.fixed(label),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
       this.expandedArg = Arg.fixed(expanded),
       this.variantArg = Arg.fixed(variant),
       this.sizeArg = Arg.fixed(size),
       this.enabledArg = Arg.fixed(enabled),
       this.borderColorArg = borderColor == null
           ? null
           : Arg.fixed(borderColor),
       this.selectedArg = selected == null ? null : Arg.fixed(selected);

  final Arg<Key?>? keyArg;

  final Arg<String> labelArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<bool> expandedArg;

  final Arg<ChipVariant> variantArg;

  final Arg<ChipSize> sizeArg;

  final Arg<bool> enabledArg;

  final Arg<Color?>? borderColorArg;

  final Arg<bool?>? selectedArg;

  Key? get key => keyArg?.value;

  String get label => labelArg.value;

  void Function()? get onTap => onTapArg?.value;

  bool get expanded => expandedArg.value;

  ChipVariant get variant => variantArg.value;

  ChipSize get size => sizeArg.value;

  bool get enabled => enabledArg.value;

  Color? get borderColor => borderColorArg?.value;

  bool? get selected => selectedArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    labelArg,
    onTapArg,
    expandedArg,
    variantArg,
    sizeArg,
    enabledArg,
    borderColorArg,
    selectedArg,
  ];
}
