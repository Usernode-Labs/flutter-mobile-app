// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'full_page_loading_state.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<FullPageLoadingState, FullPageLoadingStateArgs>;
typedef _Scenario = FullPageLoadingStateScenario;
typedef _Defaults = FullPageLoadingStateDefaults;
typedef _Story = FullPageLoadingStateStory;
typedef _Args = FullPageLoadingStateArgs;
final FullPageLoadingStateComponent =
    Component<FullPageLoadingState, FullPageLoadingStateArgs>(
      name: meta.name ?? 'FullPageLoadingState',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: r'''A centered loading indicator for use as a full-page body.

Designed for the `body:` slot of a [Scaffold] when the entire screen
is waiting for data. For inline/partial loading, use a local
[CircularProgressIndicator] directly.

Presentation-only — takes all state via constructor params.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef FullPageLoadingStateScenario =
    Scenario<FullPageLoadingState, FullPageLoadingStateArgs>;
typedef FullPageLoadingStateDefaults =
    Defaults<FullPageLoadingState, FullPageLoadingStateArgs>;

class FullPageLoadingStateStory
    extends Story<FullPageLoadingState, FullPageLoadingStateArgs> {
  FullPageLoadingStateStory({
    super.name,
    super.setup,
    super.modes,
    FullPageLoadingStateArgs? args,
    StoryWidgetBuilder<FullPageLoadingState, FullPageLoadingStateArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? FullPageLoadingStateArgs(),
         builder:
             builder ?? (context, args) => FullPageLoadingState(key: args.key),
       );
}

class FullPageLoadingStateArgs extends StoryArgs<FullPageLoadingState> {
  FullPageLoadingStateArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  FullPageLoadingStateArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
