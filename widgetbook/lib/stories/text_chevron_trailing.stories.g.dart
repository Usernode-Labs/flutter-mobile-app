// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'text_chevron_trailing.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<TextChevronTrailing, TextChevronTrailingArgs>;
typedef _Scenario = TextChevronTrailingScenario;
typedef _Defaults = TextChevronTrailingDefaults;
typedef _Story = TextChevronTrailingStory;
typedef _Args = TextChevronTrailingArgs;
final TextChevronTrailingComponent =
    Component<TextChevronTrailing, TextChevronTrailingArgs>(
  name: meta.name ?? 'TextChevronTrailing',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A trailing widget that shows text followed by a chevron-right icon.

Commonly used as `ListTile.trailing` to indicate a tappable row that
navigates somewhere while still displaying a value.

Presentation-only — takes all state via constructor params.''',
  stories: [$Default..$generatedName = 'Default'],
);
typedef TextChevronTrailingScenario
    = Scenario<TextChevronTrailing, TextChevronTrailingArgs>;
typedef TextChevronTrailingDefaults
    = Defaults<TextChevronTrailing, TextChevronTrailingArgs>;

class TextChevronTrailingStory
    extends Story<TextChevronTrailing, TextChevronTrailingArgs> {
  TextChevronTrailingStory({
    super.name,
    super.setup,
    super.modes,
    TextChevronTrailingArgs? args,
    StoryWidgetBuilder<TextChevronTrailing, TextChevronTrailingArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? TextChevronTrailingArgs(),
          builder: builder ??
              (context, args) =>
                  TextChevronTrailing(key: args.key, text: args.text),
        );
}

class TextChevronTrailingArgs extends StoryArgs<TextChevronTrailing> {
  TextChevronTrailingArgs({Arg<Key?>? key, Arg<String>? text})
      : this.keyArg = $initArg('key', key, null),
        this.textArg = $initArg('text', text, StringArg(''))!;

  TextChevronTrailingArgs.fixed({Key? key, String text = ''})
      : this.keyArg = key == null ? null : Arg.fixed(key),
        this.textArg = Arg.fixed(text);

  final Arg<Key?>? keyArg;

  final Arg<String> textArg;

  Key? get key => keyArg?.value;

  String get text => textArg.value;

  @override
  List<Arg?> get list => [keyArg, textArg];
}
