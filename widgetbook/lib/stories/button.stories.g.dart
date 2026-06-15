// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'button.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<Button, ButtonArgs>;
typedef _Scenario = ButtonScenario;
typedef _Defaults = ButtonDefaults;
typedef _Story = ButtonStory;
typedef _Args = ButtonArgs;
final ButtonComponent = Component<Button, ButtonArgs>(
  name: meta.name ?? 'Button',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''A design system button backed by M3 Material components.

Supports three sizes ([ButtonSize]) and four variants ([ButtonVariant]).
Provides ink splash, focus/hover states, and accessibility semantics via
[FilledButton] / [OutlinedButton].''',
  stories: [
    $Playground..$generatedName = 'Playground',
    $WithIcon..$generatedName = 'WithIcon',
    $AllVariants..$generatedName = 'AllVariants',
  ],
);
typedef ButtonScenario = Scenario<Button, ButtonArgs>;
typedef ButtonDefaults = Defaults<Button, ButtonArgs>;

class ButtonStory extends Story<Button, ButtonArgs> {
  ButtonStory({
    super.name,
    super.setup,
    super.modes,
    ButtonArgs? args,
    StoryWidgetBuilder<Button, ButtonArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ButtonArgs(),
         builder:
             builder ??
             (context, args) => Button(
               key: args.key,
               label: args.label,
               onTap: args.onTap,
               leadingIcon: args.leadingIcon,
               size: args.size,
               variant: args.variant,
               isLoading: args.isLoading,
             ),
       );
}

class ButtonArgs extends StoryArgs<Button> {
  ButtonArgs({
    Arg<Key?>? key,
    Arg<String>? label,
    Arg<void Function()?>? onTap,
    Arg<Widget?>? leadingIcon,
    Arg<ButtonSize>? size,
    Arg<ButtonVariant>? variant,
    Arg<bool>? isLoading,
  }) : this.keyArg = $initArg('key', key, null),
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.onTapArg = $initArg('onTap', onTap, null),
       this.leadingIconArg = $initArg('leadingIcon', leadingIcon, null),
       this.sizeArg = $initArg(
         'size',
         size,
         EnumArg<ButtonSize>(ButtonSize.regular, values: ButtonSize.values),
       )!,
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<ButtonVariant>(
           ButtonVariant.tonal,
           values: ButtonVariant.values,
         ),
       )!,
       this.isLoadingArg = $initArg('isLoading', isLoading, BoolArg(false))!;

  ButtonArgs.fixed({
    Key? key,
    String label = '',
    void Function()? onTap,
    Widget? leadingIcon,
    ButtonSize size = ButtonSize.regular,
    ButtonVariant variant = ButtonVariant.tonal,
    bool isLoading = false,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.labelArg = Arg.fixed(label),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
       this.leadingIconArg = leadingIcon == null
           ? null
           : Arg.fixed(leadingIcon),
       this.sizeArg = Arg.fixed(size),
       this.variantArg = Arg.fixed(variant),
       this.isLoadingArg = Arg.fixed(isLoading);

  final Arg<Key?>? keyArg;

  final Arg<String> labelArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<Widget?>? leadingIconArg;

  final Arg<ButtonSize> sizeArg;

  final Arg<ButtonVariant> variantArg;

  final Arg<bool> isLoadingArg;

  Key? get key => keyArg?.value;

  String get label => labelArg.value;

  void Function()? get onTap => onTapArg?.value;

  Widget? get leadingIcon => leadingIconArg?.value;

  ButtonSize get size => sizeArg.value;

  ButtonVariant get variant => variantArg.value;

  bool get isLoading => isLoadingArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    labelArg,
    onTapArg,
    leadingIconArg,
    sizeArg,
    variantArg,
    isLoadingArg,
  ];
}
