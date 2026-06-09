// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'list_section_header.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ListSectionHeader, ListSectionHeaderArgs>;
typedef _Scenario = ListSectionHeaderScenario;
typedef _Defaults = ListSectionHeaderDefaults;
typedef _Story = ListSectionHeaderStory;
typedef _Args = ListSectionHeaderArgs;
final ListSectionHeaderComponent =
    Component<ListSectionHeader, ListSectionHeaderArgs>(
      name: meta.name ?? 'ListSectionHeader',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Section header for grouped lists — renders [title] in `labelLarge` /
`onSurfaceVariant` with bottom spacing.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ListSectionHeaderScenario =
    Scenario<ListSectionHeader, ListSectionHeaderArgs>;
typedef ListSectionHeaderDefaults =
    Defaults<ListSectionHeader, ListSectionHeaderArgs>;

class ListSectionHeaderStory
    extends Story<ListSectionHeader, ListSectionHeaderArgs> {
  ListSectionHeaderStory({
    super.name,
    super.setup,
    super.modes,
    ListSectionHeaderArgs? args,
    StoryWidgetBuilder<ListSectionHeader, ListSectionHeaderArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? ListSectionHeaderArgs(),
         builder:
             builder ??
             (context, args) =>
                 ListSectionHeader(key: args.key, title: args.title),
       );
}

class ListSectionHeaderArgs extends StoryArgs<ListSectionHeader> {
  ListSectionHeaderArgs({Arg<Key?>? key, Arg<String>? title})
    : this.keyArg = $initArg('key', key, null),
      this.titleArg = $initArg('title', title, StringArg(''))!;

  ListSectionHeaderArgs.fixed({Key? key, String title = ''})
    : this.keyArg = key == null ? null : Arg.fixed(key),
      this.titleArg = Arg.fixed(title);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  @override
  List<Arg?> get list => [keyArg, titleArg];
}
