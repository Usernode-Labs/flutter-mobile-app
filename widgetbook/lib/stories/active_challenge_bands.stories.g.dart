// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'active_challenge_bands.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ActiveChallengeBands, ActiveChallengeBandsArgs>;
typedef _Scenario = ActiveChallengeBandsScenario;
typedef _Defaults = ActiveChallengeBandsDefaults;
typedef _Story = ActiveChallengeBandsStory;
typedef _Args = ActiveChallengeBandsArgs;
final ActiveChallengeBandsComponent =
    Component<ActiveChallengeBands, ActiveChallengeBandsArgs>(
      name: meta.name ?? 'ActiveChallengeBands',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Widgetbook-only preview of the active Fair Rewards challenge surface.

Deadlines live at the band layer; atomic cards stay focused on progress and
reward state.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ActiveChallengeBandsScenario =
    Scenario<ActiveChallengeBands, ActiveChallengeBandsArgs>;
typedef ActiveChallengeBandsDefaults =
    Defaults<ActiveChallengeBands, ActiveChallengeBandsArgs>;

class ActiveChallengeBandsStory
    extends Story<ActiveChallengeBands, ActiveChallengeBandsArgs> {
  ActiveChallengeBandsStory({
    super.name,
    super.setup,
    super.modes,
    ActiveChallengeBandsArgs? args,
    StoryWidgetBuilder<ActiveChallengeBands, ActiveChallengeBandsArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ActiveChallengeBandsArgs(),
         builder:
             builder ?? (context, args) => ActiveChallengeBands(key: args.key),
       );
}

class ActiveChallengeBandsArgs extends StoryArgs<ActiveChallengeBands> {
  ActiveChallengeBandsArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  ActiveChallengeBandsArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
