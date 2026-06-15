// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'status_badge.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StatusBadge, StatusBadgeArgs>;
typedef _Scenario = StatusBadgeScenario;
typedef _Defaults = StatusBadgeDefaults;
typedef _Story = StatusBadgeStory;
typedef _Args = StatusBadgeArgs;
final StatusBadgeComponent = Component<StatusBadge, StatusBadgeArgs>(
  name: meta.name ?? 'StatusBadge',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A compact colored pill showing a status label with optional icon.

Maps each [StatusBadgeVariant] to semantic colors from the theme,
eliminating hardcoded `Colors.*` for status indicators.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Error..$generatedName = 'Error',
    $Warning..$generatedName = 'Warning',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef StatusBadgeScenario = Scenario<StatusBadge, StatusBadgeArgs>;
typedef StatusBadgeDefaults = Defaults<StatusBadge, StatusBadgeArgs>;

class StatusBadgeStory extends Story<StatusBadge, StatusBadgeArgs> {
  StatusBadgeStory({
    super.name,
    super.setup,
    super.modes,
    StatusBadgeArgs? args,
    StoryWidgetBuilder<StatusBadge, StatusBadgeArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? StatusBadgeArgs(),
         builder:
             builder ??
             (context, args) => StatusBadge(
               key: args.key,
               label: args.label,
               variant: args.variant,
               icon: args.icon,
             ),
       );
}

class StatusBadgeArgs extends StoryArgs<StatusBadge> {
  StatusBadgeArgs({
    Arg<Key?>? key,
    Arg<String>? label,
    Arg<StatusBadgeVariant>? variant,
    Arg<IconData?>? icon,
  }) : this.keyArg = $initArg('key', key, null),
       this.labelArg = $initArg('label', label, StringArg(''))!,
       this.variantArg = $initArg(
         'variant',
         variant,
         EnumArg<StatusBadgeVariant>(
           StatusBadgeVariant.success,
           values: StatusBadgeVariant.values,
         ),
       )!,
       this.iconArg = $initArg('icon', icon, null);

  StatusBadgeArgs.fixed({
    Key? key,
    String label = '',
    StatusBadgeVariant variant = StatusBadgeVariant.success,
    IconData? icon,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.labelArg = Arg.fixed(label),
       this.variantArg = Arg.fixed(variant),
       this.iconArg = icon == null ? null : Arg.fixed(icon);

  final Arg<Key?>? keyArg;

  final Arg<String> labelArg;

  final Arg<StatusBadgeVariant> variantArg;

  final Arg<IconData?>? iconArg;

  Key? get key => keyArg?.value;

  String get label => labelArg.value;

  StatusBadgeVariant get variant => variantArg.value;

  IconData? get icon => iconArg?.value;

  @override
  List<Arg?> get list => [keyArg, labelArg, variantArg, iconArg];
}
