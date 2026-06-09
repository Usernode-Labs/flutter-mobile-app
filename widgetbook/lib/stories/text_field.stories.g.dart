// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'text_field.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DSTextField, DSTextFieldArgs>;
typedef _Scenario = DSTextFieldScenario;
typedef _Defaults = DSTextFieldDefaults;
typedef _Story = DSTextFieldStory;
typedef _Args = DSTextFieldArgs;
final DSTextFieldComponent = Component<DSTextField, DSTextFieldArgs>(
  name: meta.name ?? 'DSTextField',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A design system text field wrapping M3 [TextFormField] with ThemeExtension
tokens for consistent styling.

Uses `OutlineInputBorder` with `AppRadii.borderRadiusMedium` and colors
from `colorScheme`.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $WithError..$generatedName = 'WithError',
    $WithIcons..$generatedName = 'WithIcons',
    $Disabled..$generatedName = 'Disabled',
  ],
);
typedef DSTextFieldScenario = Scenario<DSTextField, DSTextFieldArgs>;
typedef DSTextFieldDefaults = Defaults<DSTextField, DSTextFieldArgs>;

class DSTextFieldStory extends Story<DSTextField, DSTextFieldArgs> {
  DSTextFieldStory({
    super.name,
    super.setup,
    super.modes,
    DSTextFieldArgs? args,
    StoryWidgetBuilder<DSTextField, DSTextFieldArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? DSTextFieldArgs(),
         builder:
             builder ??
             (context, args) => DSTextField(
               key: args.key,
               controller: args.controller,
               label: args.label,
               hint: args.hint,
               helperText: args.helperText,
               errorText: args.errorText,
               prefixIcon: args.prefixIcon,
               suffixIcon: args.suffixIcon,
               obscureText: args.obscureText,
               readOnly: args.readOnly,
               keyboardType: args.keyboardType,
               textInputAction: args.textInputAction,
               onChanged: args.onChanged,
               onSubmitted: args.onSubmitted,
               onTap: args.onTap,
               validator: args.validator,
               inputFormatters: args.inputFormatters,
               maxLines: args.maxLines,
               minLines: args.minLines,
               enabled: args.enabled,
               focusNode: args.focusNode,
             ),
       );
}

class DSTextFieldArgs extends StoryArgs<DSTextField> {
  DSTextFieldArgs({
    Arg<Key?>? key,
    Arg<TextEditingController?>? controller,
    Arg<String?>? label,
    Arg<String?>? hint,
    Arg<String?>? helperText,
    Arg<String?>? errorText,
    Arg<Widget?>? prefixIcon,
    Arg<Widget?>? suffixIcon,
    Arg<bool>? obscureText,
    Arg<bool>? readOnly,
    Arg<TextInputType?>? keyboardType,
    Arg<TextInputAction?>? textInputAction,
    Arg<void Function(String)?>? onChanged,
    Arg<void Function(String)?>? onSubmitted,
    Arg<void Function()?>? onTap,
    Arg<String? Function(String?)?>? validator,
    Arg<List<TextInputFormatter>?>? inputFormatters,
    Arg<int?>? maxLines,
    Arg<int?>? minLines,
    Arg<bool>? enabled,
    Arg<FocusNode?>? focusNode,
  }) : this.keyArg = $initArg('key', key, null),
       this.controllerArg = $initArg('controller', controller, null),
       this.labelArg = $initArg('label', label, NullableStringArg(null))!,
       this.hintArg = $initArg('hint', hint, NullableStringArg(null))!,
       this.helperTextArg = $initArg(
         'helperText',
         helperText,
         NullableStringArg(null),
       )!,
       this.errorTextArg = $initArg(
         'errorText',
         errorText,
         NullableStringArg(null),
       )!,
       this.prefixIconArg = $initArg('prefixIcon', prefixIcon, null),
       this.suffixIconArg = $initArg('suffixIcon', suffixIcon, null),
       this.obscureTextArg = $initArg(
         'obscureText',
         obscureText,
         BoolArg(false),
       )!,
       this.readOnlyArg = $initArg('readOnly', readOnly, BoolArg(false))!,
       this.keyboardTypeArg = $initArg('keyboardType', keyboardType, null),
       this.textInputActionArg = $initArg(
         'textInputAction',
         textInputAction,
         NullableEnumArg<TextInputAction>(null, values: TextInputAction.values),
       )!,
       this.onChangedArg = $initArg('onChanged', onChanged, null),
       this.onSubmittedArg = $initArg('onSubmitted', onSubmitted, null),
       this.onTapArg = $initArg('onTap', onTap, null),
       this.validatorArg = $initArg('validator', validator, null),
       this.inputFormattersArg = $initArg(
         'inputFormatters',
         inputFormatters,
         null,
       ),
       this.maxLinesArg = $initArg('maxLines', maxLines, NullableIntArg(1))!,
       this.minLinesArg = $initArg('minLines', minLines, NullableIntArg(null))!,
       this.enabledArg = $initArg('enabled', enabled, BoolArg(true))!,
       this.focusNodeArg = $initArg('focusNode', focusNode, null);

  DSTextFieldArgs.fixed({
    Key? key,
    TextEditingController? controller,
    String? label = null,
    String? hint = null,
    String? helperText = null,
    String? errorText = null,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction = null,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
    void Function()? onTap,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines = 1,
    int? minLines = null,
    bool enabled = true,
    FocusNode? focusNode,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.controllerArg = controller == null ? null : Arg.fixed(controller),
       this.labelArg = label == null ? null : Arg.fixed(label),
       this.hintArg = hint == null ? null : Arg.fixed(hint),
       this.helperTextArg = helperText == null ? null : Arg.fixed(helperText),
       this.errorTextArg = errorText == null ? null : Arg.fixed(errorText),
       this.prefixIconArg = prefixIcon == null ? null : Arg.fixed(prefixIcon),
       this.suffixIconArg = suffixIcon == null ? null : Arg.fixed(suffixIcon),
       this.obscureTextArg = Arg.fixed(obscureText),
       this.readOnlyArg = Arg.fixed(readOnly),
       this.keyboardTypeArg = keyboardType == null
           ? null
           : Arg.fixed(keyboardType),
       this.textInputActionArg = textInputAction == null
           ? null
           : Arg.fixed(textInputAction),
       this.onChangedArg = onChanged == null ? null : Arg.fixed(onChanged),
       this.onSubmittedArg = onSubmitted == null
           ? null
           : Arg.fixed(onSubmitted),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
       this.validatorArg = validator == null ? null : Arg.fixed(validator),
       this.inputFormattersArg = inputFormatters == null
           ? null
           : Arg.fixed(inputFormatters),
       this.maxLinesArg = maxLines == null ? null : Arg.fixed(maxLines),
       this.minLinesArg = minLines == null ? null : Arg.fixed(minLines),
       this.enabledArg = Arg.fixed(enabled),
       this.focusNodeArg = focusNode == null ? null : Arg.fixed(focusNode);

  final Arg<Key?>? keyArg;

  final Arg<TextEditingController?>? controllerArg;

  final Arg<String?>? labelArg;

  final Arg<String?>? hintArg;

  final Arg<String?>? helperTextArg;

  final Arg<String?>? errorTextArg;

  final Arg<Widget?>? prefixIconArg;

  final Arg<Widget?>? suffixIconArg;

  final Arg<bool> obscureTextArg;

  final Arg<bool> readOnlyArg;

  final Arg<TextInputType?>? keyboardTypeArg;

  final Arg<TextInputAction?>? textInputActionArg;

  final Arg<void Function(String)?>? onChangedArg;

  final Arg<void Function(String)?>? onSubmittedArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<String? Function(String?)?>? validatorArg;

  final Arg<List<TextInputFormatter>?>? inputFormattersArg;

  final Arg<int?>? maxLinesArg;

  final Arg<int?>? minLinesArg;

  final Arg<bool> enabledArg;

  final Arg<FocusNode?>? focusNodeArg;

  Key? get key => keyArg?.value;

  TextEditingController? get controller => controllerArg?.value;

  String? get label => labelArg?.value;

  String? get hint => hintArg?.value;

  String? get helperText => helperTextArg?.value;

  String? get errorText => errorTextArg?.value;

  Widget? get prefixIcon => prefixIconArg?.value;

  Widget? get suffixIcon => suffixIconArg?.value;

  bool get obscureText => obscureTextArg.value;

  bool get readOnly => readOnlyArg.value;

  TextInputType? get keyboardType => keyboardTypeArg?.value;

  TextInputAction? get textInputAction => textInputActionArg?.value;

  void Function(String)? get onChanged => onChangedArg?.value;

  void Function(String)? get onSubmitted => onSubmittedArg?.value;

  void Function()? get onTap => onTapArg?.value;

  String? Function(String?)? get validator => validatorArg?.value;

  List<TextInputFormatter>? get inputFormatters => inputFormattersArg?.value;

  int? get maxLines => maxLinesArg?.value;

  int? get minLines => minLinesArg?.value;

  bool get enabled => enabledArg.value;

  FocusNode? get focusNode => focusNodeArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    controllerArg,
    labelArg,
    hintArg,
    helperTextArg,
    errorTextArg,
    prefixIconArg,
    suffixIconArg,
    obscureTextArg,
    readOnlyArg,
    keyboardTypeArg,
    textInputActionArg,
    onChangedArg,
    onSubmittedArg,
    onTapArg,
    validatorArg,
    inputFormattersArg,
    maxLinesArg,
    minLinesArg,
    enabledArg,
    focusNodeArg,
  ];
}
