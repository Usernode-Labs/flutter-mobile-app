// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'sheet_layout.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SheetLayout, SheetLayoutArgs>;
typedef _Scenario = SheetLayoutScenario;
typedef _Defaults = SheetLayoutDefaults;
typedef _Story = SheetLayoutStory;
typedef _Args = SheetLayoutArgs;
final SheetLayoutComponent = Component<SheetLayout, SheetLayoutArgs>(
  name: meta.name ?? 'SheetLayout',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: r'''Lightweight layout scaffold for bottom sheet content.

Provides [SafeArea], optional [title] header, and wraps the [child] in
[Flexible] so it works inside the [Column] that bottom sheets use.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Default..$generatedName = 'Default',
    $NoTitle..$generatedName = 'NoTitle',
  ],
);
typedef SheetLayoutScenario = Scenario<SheetLayout, SheetLayoutArgs>;
typedef SheetLayoutDefaults = Defaults<SheetLayout, SheetLayoutArgs>;

class SheetLayoutStory extends Story<SheetLayout, SheetLayoutArgs> {
  SheetLayoutStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<SheetLayout, SheetLayoutArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => SheetLayout(
                    key: args.key,
                    title: args.title,
                    child: args.child,
                  ),
        );
}

class SheetLayoutArgs extends StoryArgs<SheetLayout> {
  SheetLayoutArgs({
    Arg<Key?>? key,
    Arg<String?>? title,
    required Arg<Widget> child,
  })  : this.keyArg = $initArg('key', key, null),
        this.titleArg = $initArg('title', title, NullableStringArg(null))!,
        this.childArg = $initArg('child', child, null)!;

  SheetLayoutArgs.fixed({Key? key, String? title = null, required Widget child})
      : this.keyArg = key == null ? null : Arg.fixed(key),
        this.titleArg = title == null ? null : Arg.fixed(title),
        this.childArg = Arg.fixed(child);

  final Arg<Key?>? keyArg;

  final Arg<String?>? titleArg;

  final Arg<Widget> childArg;

  Key? get key => keyArg?.value;

  String? get title => titleArg?.value;

  Widget get child => childArg.value;

  @override
  List<Arg?> get list => [keyArg, titleArg, childArg];
}
