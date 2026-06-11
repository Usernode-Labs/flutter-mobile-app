// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dropdown_sheet.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DropdownSheetDemo, DropdownSheetDemoArgs>;
typedef _Scenario = DropdownSheetDemoScenario;
typedef _Defaults = DropdownSheetDemoDefaults;
typedef _Story = DropdownSheetDemoStory;
typedef _Args = DropdownSheetDemoArgs;
final DropdownSheetDemoComponent =
    Component<DropdownSheetDemo, DropdownSheetDemoArgs>(
  name: meta.name ?? 'DropdownSheetDemo',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''Wrapper widget for showcasing showDropdownSheet() in Widgetbook.
Since showDropdownSheet is a function, not a widget, we wrap it.''',
  stories: [
    $Default..$generatedName = 'Default',
    $WithDivider..$generatedName = 'WithDivider',
  ],
);
typedef DropdownSheetDemoScenario
    = Scenario<DropdownSheetDemo, DropdownSheetDemoArgs>;
typedef DropdownSheetDemoDefaults
    = Defaults<DropdownSheetDemo, DropdownSheetDemoArgs>;

class DropdownSheetDemoStory
    extends Story<DropdownSheetDemo, DropdownSheetDemoArgs> {
  DropdownSheetDemoStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<DropdownSheetDemo, DropdownSheetDemoArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => DropdownSheetDemo(
                    key: args.key,
                    labels: args.labels,
                    title: args.title,
                    selectedIndex: args.selectedIndex,
                    dividerAfterIndex: args.dividerAfterIndex,
                  ),
        );
}

class DropdownSheetDemoArgs extends StoryArgs<DropdownSheetDemo> {
  DropdownSheetDemoArgs({
    Arg<Key?>? key,
    required Arg<List<String>> labels,
    Arg<String?>? title,
    Arg<int?>? selectedIndex,
    Arg<int?>? dividerAfterIndex,
  })  : this.keyArg = $initArg('key', key, null),
        this.labelsArg = $initArg('labels', labels, null)!,
        this.titleArg = $initArg('title', title, NullableStringArg(null))!,
        this.selectedIndexArg = $initArg(
          'selectedIndex',
          selectedIndex,
          NullableIntArg(null),
        )!,
        this.dividerAfterIndexArg = $initArg(
          'dividerAfterIndex',
          dividerAfterIndex,
          NullableIntArg(null),
        )!;

  DropdownSheetDemoArgs.fixed({
    Key? key,
    required List<String> labels,
    String? title = null,
    int? selectedIndex = null,
    int? dividerAfterIndex = null,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.labelsArg = Arg.fixed(labels),
        this.titleArg = title == null ? null : Arg.fixed(title),
        this.selectedIndexArg =
            selectedIndex == null ? null : Arg.fixed(selectedIndex),
        this.dividerAfterIndexArg =
            dividerAfterIndex == null ? null : Arg.fixed(dividerAfterIndex);

  final Arg<Key?>? keyArg;

  final Arg<List<String>> labelsArg;

  final Arg<String?>? titleArg;

  final Arg<int?>? selectedIndexArg;

  final Arg<int?>? dividerAfterIndexArg;

  Key? get key => keyArg?.value;

  List<String> get labels => labelsArg.value;

  String? get title => titleArg?.value;

  int? get selectedIndex => selectedIndexArg?.value;

  int? get dividerAfterIndex => dividerAfterIndexArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        labelsArg,
        titleArg,
        selectedIndexArg,
        dividerAfterIndexArg,
      ];
}
