// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'slot_assignments_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SlotAssignmentsPage, SlotAssignmentsPageArgs>;
typedef _Scenario = SlotAssignmentsPageScenario;
typedef _Defaults = SlotAssignmentsPageDefaults;
typedef _Story = SlotAssignmentsPageStory;
typedef _Args = SlotAssignmentsPageArgs;
final SlotAssignmentsPageComponent =
    Component<SlotAssignmentsPage, SlotAssignmentsPageArgs>(
  name: meta.name ?? 'SlotAssignmentsPage',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A full-page slot assignments view with epoch progress header, filter chips,
and a scrollable list of slot items.

Presentation-only: all data comes through constructor parameters.
The feature screen in `lib/features/` wires state to this widget.''',
  stories: [
    $Default..$generatedName = 'Default',
    $WithHighlight..$generatedName = 'WithHighlight',
    $Empty..$generatedName = 'Empty',
  ],
);
typedef SlotAssignmentsPageScenario
    = Scenario<SlotAssignmentsPage, SlotAssignmentsPageArgs>;
typedef SlotAssignmentsPageDefaults
    = Defaults<SlotAssignmentsPage, SlotAssignmentsPageArgs>;

class SlotAssignmentsPageStory
    extends Story<SlotAssignmentsPage, SlotAssignmentsPageArgs> {
  SlotAssignmentsPageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<SlotAssignmentsPage, SlotAssignmentsPageArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => SlotAssignmentsPage(
                    key: args.key,
                    title: args.title,
                    epochLabel: args.epochLabel,
                    slotProgressLeftLabel: args.slotProgressLeftLabel,
                    slotProgress: args.slotProgress,
                    filters: args.filters,
                    onFilterTap: args.onFilterTap,
                    items: args.items,
                    slotProgressRightLabel: args.slotProgressRightLabel,
                    onItemTap: args.onItemTap,
                    onBackTap: args.onBackTap,
                    highlightIndex: args.highlightIndex,
                  ),
        );
}

class SlotAssignmentsPageArgs extends StoryArgs<SlotAssignmentsPage> {
  SlotAssignmentsPageArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    Arg<String>? epochLabel,
    Arg<String>? slotProgressLeftLabel,
    Arg<double>? slotProgress,
    required Arg<List<SlotFilterData>> filters,
    required Arg<void Function(int)> onFilterTap,
    required Arg<List<SlotAssignmentItemData>> items,
    Arg<String?>? slotProgressRightLabel,
    Arg<void Function(int)?>? onItemTap,
    Arg<void Function()?>? onBackTap,
    Arg<int?>? highlightIndex,
  })  : this.keyArg = $initArg('key', key, null),
        this.titleArg = $initArg('title', title, StringArg(''))!,
        this.epochLabelArg = $initArg('epochLabel', epochLabel, StringArg(''))!,
        this.slotProgressLeftLabelArg = $initArg(
          'slotProgressLeftLabel',
          slotProgressLeftLabel,
          StringArg(''),
        )!,
        this.slotProgressArg = $initArg(
          'slotProgress',
          slotProgress,
          DoubleArg(0.0),
        )!,
        this.filtersArg = $initArg('filters', filters, null)!,
        this.onFilterTapArg = $initArg('onFilterTap', onFilterTap, null)!,
        this.itemsArg = $initArg('items', items, null)!,
        this.slotProgressRightLabelArg = $initArg(
          'slotProgressRightLabel',
          slotProgressRightLabel,
          NullableStringArg(null),
        )!,
        this.onItemTapArg = $initArg('onItemTap', onItemTap, null),
        this.onBackTapArg = $initArg('onBackTap', onBackTap, null),
        this.highlightIndexArg = $initArg(
          'highlightIndex',
          highlightIndex,
          NullableIntArg(null),
        )!;

  SlotAssignmentsPageArgs.fixed({
    Key? key,
    String title = '',
    String epochLabel = '',
    String slotProgressLeftLabel = '',
    double slotProgress = 0.0,
    required List<SlotFilterData> filters,
    required void Function(int) onFilterTap,
    required List<SlotAssignmentItemData> items,
    String? slotProgressRightLabel = null,
    void Function(int)? onItemTap,
    void Function()? onBackTap,
    int? highlightIndex = null,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.titleArg = Arg.fixed(title),
        this.epochLabelArg = Arg.fixed(epochLabel),
        this.slotProgressLeftLabelArg = Arg.fixed(slotProgressLeftLabel),
        this.slotProgressArg = Arg.fixed(slotProgress),
        this.filtersArg = Arg.fixed(filters),
        this.onFilterTapArg = Arg.fixed(onFilterTap),
        this.itemsArg = Arg.fixed(items),
        this.slotProgressRightLabelArg = slotProgressRightLabel == null
            ? null
            : Arg.fixed(slotProgressRightLabel),
        this.onItemTapArg = onItemTap == null ? null : Arg.fixed(onItemTap),
        this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap),
        this.highlightIndexArg =
            highlightIndex == null ? null : Arg.fixed(highlightIndex);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<String> epochLabelArg;

  final Arg<String> slotProgressLeftLabelArg;

  final Arg<double> slotProgressArg;

  final Arg<List<SlotFilterData>> filtersArg;

  final Arg<void Function(int)> onFilterTapArg;

  final Arg<List<SlotAssignmentItemData>> itemsArg;

  final Arg<String?>? slotProgressRightLabelArg;

  final Arg<void Function(int)?>? onItemTapArg;

  final Arg<void Function()?>? onBackTapArg;

  final Arg<int?>? highlightIndexArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  String get epochLabel => epochLabelArg.value;

  String get slotProgressLeftLabel => slotProgressLeftLabelArg.value;

  double get slotProgress => slotProgressArg.value;

  List<SlotFilterData> get filters => filtersArg.value;

  void Function(int) get onFilterTap => onFilterTapArg.value;

  List<SlotAssignmentItemData> get items => itemsArg.value;

  String? get slotProgressRightLabel => slotProgressRightLabelArg?.value;

  void Function(int)? get onItemTap => onItemTapArg?.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  int? get highlightIndex => highlightIndexArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        titleArg,
        epochLabelArg,
        slotProgressLeftLabelArg,
        slotProgressArg,
        filtersArg,
        onFilterTapArg,
        itemsArg,
        slotProgressRightLabelArg,
        onItemTapArg,
        onBackTapArg,
        highlightIndexArg,
      ];
}
