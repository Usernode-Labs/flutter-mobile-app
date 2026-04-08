// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dapp_avatar.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DappAvatar, DappAvatarArgs>;
typedef _Scenario = DappAvatarScenario;
typedef _Defaults = DappAvatarDefaults;
typedef _Story = DappAvatarStory;
typedef _Args = DappAvatarArgs;
final DappAvatarComponent = Component<DappAvatar, DappAvatarArgs>(
  name: meta.name ?? 'DappAvatar',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''Generates a unique gradient avatar with a two-letter monogram for a dApp.

Colors are drawn from [AppSemanticColors] (technical, flash, community) so
avatars feel native to the design system across light/dark themes. Each seed
deterministically picks two semantic colors and a gradient angle.

The monogram is derived from [seed]: first letters of the first two words,
or the first two characters if single-word.''',
  stories: [
    $Default..$generatedName = 'Default',
    $SingleWord..$generatedName = 'SingleWord',
    $Large..$generatedName = 'Large',
  ],
);
typedef DappAvatarScenario = Scenario<DappAvatar, DappAvatarArgs>;
typedef DappAvatarDefaults = Defaults<DappAvatar, DappAvatarArgs>;

class DappAvatarStory extends Story<DappAvatar, DappAvatarArgs> {
  DappAvatarStory({
    super.name,
    super.setup,
    super.modes,
    DappAvatarArgs? args,
    StoryWidgetBuilder<DappAvatar, DappAvatarArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? DappAvatarArgs(),
         builder:
             builder ??
             (context, args) =>
                 DappAvatar(key: args.key, seed: args.seed, size: args.size),
       );
}

class DappAvatarArgs extends StoryArgs<DappAvatar> {
  DappAvatarArgs({Arg<Key?>? key, Arg<String>? seed, Arg<double?>? size})
    : this.keyArg = $initArg('key', key, null),
      this.seedArg = $initArg('seed', seed, StringArg(''))!,
      this.sizeArg = $initArg('size', size, NullableDoubleArg(null))!;

  DappAvatarArgs.fixed({Key? key, String seed = '', double? size = null})
    : this.keyArg = key == null ? null : Arg.fixed(key),
      this.seedArg = Arg.fixed(seed),
      this.sizeArg = size == null ? null : Arg.fixed(size);

  final Arg<Key?>? keyArg;

  final Arg<String> seedArg;

  final Arg<double?>? sizeArg;

  Key? get key => keyArg?.value;

  String get seed => seedArg.value;

  double? get size => sizeArg?.value;

  @override
  List<Arg?> get list => [keyArg, seedArg, sizeArg];
}
