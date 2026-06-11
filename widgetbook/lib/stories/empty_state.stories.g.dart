// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'empty_state.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<EmptyState, EmptyStateArgs>;
typedef _Scenario = EmptyStateScenario;
typedef _Defaults = EmptyStateDefaults;
typedef _Story = EmptyStateStory;
typedef _Args = EmptyStateArgs;
final EmptyStateComponent = Component<EmptyState, EmptyStateArgs>(
  name: meta.name ?? 'EmptyState',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A centered empty-state placeholder with optional icon, title, optional
subtitle, and optional action button.

Used when a list, page, or section has no content to display.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $WithAction..$generatedName = 'WithAction',
    $Minimal..$generatedName = 'Minimal',
  ],
);
typedef EmptyStateScenario = Scenario<EmptyState, EmptyStateArgs>;
typedef EmptyStateDefaults = Defaults<EmptyState, EmptyStateArgs>;

class EmptyStateStory extends Story<EmptyState, EmptyStateArgs> {
  EmptyStateStory({
    super.name,
    super.setup,
    super.modes,
    EmptyStateArgs? args,
    StoryWidgetBuilder<EmptyState, EmptyStateArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? EmptyStateArgs(),
          builder: builder ??
              (context, args) => EmptyState(
                    key: args.key,
                    icon: args.icon,
                    title: args.title,
                    subtitle: args.subtitle,
                    action: args.action,
                  ),
        );
}

class EmptyStateArgs extends StoryArgs<EmptyState> {
  EmptyStateArgs({
    Arg<Key?>? key,
    Arg<IconData?>? icon,
    Arg<String>? title,
    Arg<String?>? subtitle,
    Arg<Widget?>? action,
  })  : this.keyArg = $initArg('key', key, null),
        this.iconArg = $initArg('icon', icon, null),
        this.titleArg = $initArg('title', title, StringArg(''))!,
        this.subtitleArg = $initArg(
          'subtitle',
          subtitle,
          NullableStringArg(null),
        )!,
        this.actionArg = $initArg('action', action, null);

  EmptyStateArgs.fixed({
    Key? key,
    IconData? icon,
    String title = '',
    String? subtitle = null,
    Widget? action,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.iconArg = icon == null ? null : Arg.fixed(icon),
        this.titleArg = Arg.fixed(title),
        this.subtitleArg = subtitle == null ? null : Arg.fixed(subtitle),
        this.actionArg = action == null ? null : Arg.fixed(action);

  final Arg<Key?>? keyArg;

  final Arg<IconData?>? iconArg;

  final Arg<String> titleArg;

  final Arg<String?>? subtitleArg;

  final Arg<Widget?>? actionArg;

  Key? get key => keyArg?.value;

  IconData? get icon => iconArg?.value;

  String get title => titleArg.value;

  String? get subtitle => subtitleArg?.value;

  Widget? get action => actionArg?.value;

  @override
  List<Arg?> get list => [keyArg, iconArg, titleArg, subtitleArg, actionArg];
}
