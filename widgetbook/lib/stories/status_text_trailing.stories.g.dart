// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'status_text_trailing.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<StatusTextTrailing, StatusTextTrailingArgs>;
typedef _Scenario = StatusTextTrailingScenario;
typedef _Defaults = StatusTextTrailingDefaults;
typedef _Story = StatusTextTrailingStory;
typedef _Args = StatusTextTrailingArgs;
final StatusTextTrailingComponent =
    Component<StatusTextTrailing, StatusTextTrailingArgs>(
  name: meta.name ?? 'StatusTextTrailing',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A trailing widget that shows a text label followed by a status icon.

Shape communicates the state (check, X, warning triangle, clock, empty
circle) so status is accessible without relying on color alone.

Commonly used as `ListTile.trailing` for pipeline step rows.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $Error..$generatedName = 'Error',
    $Warning..$generatedName = 'Warning',
    $Info..$generatedName = 'Info',
    $Neutral..$generatedName = 'Neutral',
  ],
);
typedef StatusTextTrailingScenario
    = Scenario<StatusTextTrailing, StatusTextTrailingArgs>;
typedef StatusTextTrailingDefaults
    = Defaults<StatusTextTrailing, StatusTextTrailingArgs>;

class StatusTextTrailingStory
    extends Story<StatusTextTrailing, StatusTextTrailingArgs> {
  StatusTextTrailingStory({
    super.name,
    super.setup,
    super.modes,
    StatusTextTrailingArgs? args,
    StoryWidgetBuilder<StatusTextTrailing, StatusTextTrailingArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? StatusTextTrailingArgs(),
          builder: builder ??
              (context, args) => StatusTextTrailing(
                    key: args.key,
                    text: args.text,
                    variant: args.variant,
                  ),
        );
}

class StatusTextTrailingArgs extends StoryArgs<StatusTextTrailing> {
  StatusTextTrailingArgs({
    Arg<Key?>? key,
    Arg<String>? text,
    Arg<StatusBadgeVariant>? variant,
  })  : this.keyArg = $initArg('key', key, null),
        this.textArg = $initArg('text', text, StringArg(''))!,
        this.variantArg = $initArg(
          'variant',
          variant,
          EnumArg<StatusBadgeVariant>(
            StatusBadgeVariant.success,
            values: StatusBadgeVariant.values,
          ),
        )!;

  StatusTextTrailingArgs.fixed({
    Key? key,
    String text = '',
    StatusBadgeVariant variant = StatusBadgeVariant.success,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.textArg = Arg.fixed(text),
        this.variantArg = Arg.fixed(variant);

  final Arg<Key?>? keyArg;

  final Arg<String> textArg;

  final Arg<StatusBadgeVariant> variantArg;

  Key? get key => keyArg?.value;

  String get text => textArg.value;

  StatusBadgeVariant get variant => variantArg.value;

  @override
  List<Arg?> get list => [keyArg, textArg, variantArg];
}
