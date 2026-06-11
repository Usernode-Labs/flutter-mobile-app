// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dropdown_chip.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DropdownChip, DropdownChipStoryModelArgs>;
typedef _Scenario = DropdownChipScenario;
typedef _Defaults = DropdownChipDefaults;
typedef _Story = DropdownChipStory;
typedef _Args = DropdownChipStoryModelArgs;
final DropdownChipComponent =
    Component<DropdownChip, DropdownChipStoryModelArgs>(
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
typedef DropdownChipScenario =
    Scenario<DropdownChip, DropdownChipStoryModelArgs>;
typedef DropdownChipDefaults =
    Defaults<DropdownChip, DropdownChipStoryModelArgs>;

class DropdownChipStory
    extends Story<DropdownChip, DropdownChipStoryModelArgs> {
  DropdownChipStory({
    super.name,
    SetupBuilder<DropdownChip, DropdownChipStoryModelArgs>? setup,
    super.modes,
    DropdownChipStoryModelArgs? args,
    StoryWidgetBuilder<DropdownChip, DropdownChipStoryModelArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? DropdownChipStoryModelArgs(),
         builder: builder ?? defaults.builder!,
       );
}

class DropdownChipStoryModelArgs extends StoryArgs<DropdownChip> {
  DropdownChipStoryModelArgs({
    Arg<String>? label,
    Arg<void Function()?>? onTap,
    Arg<bool>? expanded,
    Arg<ChipVariant>? variant,
    Arg<ChipSize>? size,
    Arg<bool>? enabled,
    Arg<Color?>? borderColor,
  }) : this.labelArg = $initArg('label', label, StringArg('Season 2'))!,
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
       )!;

  DropdownChipStoryModelArgs.fixed({
    String label = 'Season 2',
    void Function()? onTap,
    bool expanded = false,
    ChipVariant variant = ChipVariant.outlined,
    ChipSize size = ChipSize.regular,
    bool enabled = true,
    Color? borderColor = null,
  }) : this.labelArg = Arg.fixed(label),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
       this.expandedArg = Arg.fixed(expanded),
       this.variantArg = Arg.fixed(variant),
       this.sizeArg = Arg.fixed(size),
       this.enabledArg = Arg.fixed(enabled),
       this.borderColorArg = borderColor == null
           ? null
           : Arg.fixed(borderColor);

  final Arg<String> labelArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<bool> expandedArg;

  final Arg<ChipVariant> variantArg;

  final Arg<ChipSize> sizeArg;

  final Arg<bool> enabledArg;

  final Arg<Color?>? borderColorArg;

  String get label => labelArg.value;

  void Function()? get onTap => onTapArg?.value;

  bool get expanded => expandedArg.value;

  ChipVariant get variant => variantArg.value;

  ChipSize get size => sizeArg.value;

  bool get enabled => enabledArg.value;

  Color? get borderColor => borderColorArg?.value;

  @override
  List<Arg?> get list => [
    labelArg,
    onTapArg,
    expandedArg,
    variantArg,
    sizeArg,
    enabledArg,
    borderColorArg,
  ];
}
