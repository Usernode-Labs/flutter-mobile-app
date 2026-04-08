// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'info_row.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<InfoRow, InfoRowArgs>;
typedef _Scenario = InfoRowScenario;
typedef _Defaults = InfoRowDefaults;
typedef _Story = InfoRowStory;
typedef _Args = InfoRowArgs;
final InfoRowComponent = Component<InfoRow, InfoRowArgs>(
  name: meta.name ?? 'InfoRow',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A key-value row displaying a label on the left and a value on the right.

Used in detail screens for displaying metadata (block hash, epoch, etc.).
Supports optional trailing widget, tap handler, and bottom divider.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Tappable..$generatedName = 'Tappable',
    $NoDivider..$generatedName = 'NoDivider',
  ],
);
typedef InfoRowScenario = Scenario<InfoRow, InfoRowArgs>;
typedef InfoRowDefaults = Defaults<InfoRow, InfoRowArgs>;

class InfoRowStory extends Story<InfoRow, InfoRowArgs> {
  InfoRowStory({
    super.name,
    super.setup,
    super.modes,
    InfoRowArgs? args,
    StoryWidgetBuilder<InfoRow, InfoRowArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? InfoRowArgs(),
         builder:
             builder ??
             (context, args) => InfoRow(
               key: args.key,
               label: args.label,
               value: args.value,
               valueStyle: args.valueStyle,
               trailing: args.trailing,
               onTap: args.onTap,
               showDivider: args.showDivider,
               contentPadding: args.contentPadding,
             ),
       );
}

class InfoRowArgs extends StoryArgs<InfoRow> {
  InfoRowArgs({
    Arg<Key?>? key,
    Arg<String>? label,
    Arg<String>? value,
    Arg<TextStyle?>? valueStyle,
    Arg<Widget?>? trailing,
    Arg<void Function()?>? onTap,
    Arg<bool>? showDivider,
    Arg<EdgeInsetsGeometry?>? contentPadding,
  }) : this.keyArg = $initArg('key', key, null),
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.valueArg = $initArg('value', value, StringArg(''))!,
       this.valueStyleArg = $initArg('valueStyle', valueStyle, null),
       this.trailingArg = $initArg('trailing', trailing, null),
       this.onTapArg = $initArg('onTap', onTap, null),
       this.showDividerArg = $initArg(
         'showDivider',
         showDivider,
         BoolArg(true),
       )!,
       this.contentPaddingArg = $initArg(
         'contentPadding',
         contentPadding,
         null,
       );

  InfoRowArgs.fixed({
    Key? key,
    String label = '',
    String value = '',
    TextStyle? valueStyle,
    Widget? trailing,
    void Function()? onTap,
    bool showDivider = true,
    EdgeInsetsGeometry? contentPadding,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.labelArg = Arg.fixed(label),
       this.valueArg = Arg.fixed(value),
       this.valueStyleArg = valueStyle == null ? null : Arg.fixed(valueStyle),
       this.trailingArg = trailing == null ? null : Arg.fixed(trailing),
       this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
       this.showDividerArg = Arg.fixed(showDivider),
       this.contentPaddingArg = contentPadding == null
           ? null
           : Arg.fixed(contentPadding);

  final Arg<Key?>? keyArg;

  final Arg<String> labelArg;

  final Arg<String> valueArg;

  final Arg<TextStyle?>? valueStyleArg;

  final Arg<Widget?>? trailingArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<bool> showDividerArg;

  final Arg<EdgeInsetsGeometry?>? contentPaddingArg;

  Key? get key => keyArg?.value;

  String get label => labelArg.value;

  String get value => valueArg.value;

  TextStyle? get valueStyle => valueStyleArg?.value;

  Widget? get trailing => trailingArg?.value;

  void Function()? get onTap => onTapArg?.value;

  bool get showDivider => showDividerArg.value;

  EdgeInsetsGeometry? get contentPadding => contentPaddingArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    labelArg,
    valueArg,
    valueStyleArg,
    trailingArg,
    onTapArg,
    showDividerArg,
    contentPaddingArg,
  ];
}
