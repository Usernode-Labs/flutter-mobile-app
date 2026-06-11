// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'epoch_performance_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<EpochPerformancePage, EpochPerformancePageArgs>;
typedef _Scenario = EpochPerformancePageScenario;
typedef _Defaults = EpochPerformancePageDefaults;
typedef _Story = EpochPerformancePageStory;
typedef _Args = EpochPerformancePageArgs;
final EpochPerformancePageComponent =
    Component<EpochPerformancePage, EpochPerformancePageArgs>(
  name: meta.name ?? 'EpochPerformancePage',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A full-page epoch performance view showing epoch progress and metric tiles.

Presentation-only: all data comes through constructor parameters.
The feature screen in `lib/features/` wires state to this widget.''',
  stories: [
    $Default..$generatedName = 'Default',
    $EarlyEpoch..$generatedName = 'EarlyEpoch',
  ],
);
typedef EpochPerformancePageScenario
    = Scenario<EpochPerformancePage, EpochPerformancePageArgs>;
typedef EpochPerformancePageDefaults
    = Defaults<EpochPerformancePage, EpochPerformancePageArgs>;

class EpochPerformancePageStory
    extends Story<EpochPerformancePage, EpochPerformancePageArgs> {
  EpochPerformancePageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<EpochPerformancePage, EpochPerformancePageArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => EpochPerformancePage(
                    key: args.key,
                    epochLabel: args.epochLabel,
                    progress: args.progress,
                    progressLeftLabel: args.progressLeftLabel,
                    progressRightLabel: args.progressRightLabel,
                    performanceLabel: args.performanceLabel,
                    performanceValue: args.performanceValue,
                    metrics: args.metrics,
                    onPickEpoch: args.onPickEpoch,
                    maxEpoch: args.maxEpoch,
                    selectedEpoch: args.selectedEpoch,
                    epochScoreLookup: args.epochScoreLookup,
                    onBackTap: args.onBackTap,
                  ),
        );
}

class EpochPerformancePageArgs extends StoryArgs<EpochPerformancePage> {
  EpochPerformancePageArgs({
    Arg<Key?>? key,
    Arg<String>? epochLabel,
    Arg<double>? progress,
    Arg<String>? progressLeftLabel,
    Arg<String>? progressRightLabel,
    Arg<String>? performanceLabel,
    Arg<String>? performanceValue,
    required Arg<List<EpochMetricData>> metrics,
    required Arg<void Function(int)> onPickEpoch,
    Arg<int>? maxEpoch,
    Arg<int>? selectedEpoch,
    Arg<String Function(int)?>? epochScoreLookup,
    Arg<void Function()?>? onBackTap,
  })  : this.keyArg = $initArg('key', key, null),
        this.epochLabelArg = $initArg('epochLabel', epochLabel, StringArg(''))!,
        this.progressArg = $initArg('progress', progress, DoubleArg(0.0))!,
        this.progressLeftLabelArg = $initArg(
          'progressLeftLabel',
          progressLeftLabel,
          StringArg(''),
        )!,
        this.progressRightLabelArg = $initArg(
          'progressRightLabel',
          progressRightLabel,
          StringArg(''),
        )!,
        this.performanceLabelArg = $initArg(
          'performanceLabel',
          performanceLabel,
          StringArg(''),
        )!,
        this.performanceValueArg = $initArg(
          'performanceValue',
          performanceValue,
          StringArg(''),
        )!,
        this.metricsArg = $initArg('metrics', metrics, null)!,
        this.onPickEpochArg = $initArg('onPickEpoch', onPickEpoch, null)!,
        this.maxEpochArg = $initArg('maxEpoch', maxEpoch, IntArg(0))!,
        this.selectedEpochArg = $initArg(
          'selectedEpoch',
          selectedEpoch,
          IntArg(0),
        )!,
        this.epochScoreLookupArg = $initArg(
          'epochScoreLookup',
          epochScoreLookup,
          null,
        ),
        this.onBackTapArg = $initArg('onBackTap', onBackTap, null);

  EpochPerformancePageArgs.fixed({
    Key? key,
    String epochLabel = '',
    double progress = 0.0,
    String progressLeftLabel = '',
    String progressRightLabel = '',
    String performanceLabel = '',
    String performanceValue = '',
    required List<EpochMetricData> metrics,
    required void Function(int) onPickEpoch,
    int maxEpoch = 0,
    int selectedEpoch = 0,
    String Function(int)? epochScoreLookup,
    void Function()? onBackTap,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.epochLabelArg = Arg.fixed(epochLabel),
        this.progressArg = Arg.fixed(progress),
        this.progressLeftLabelArg = Arg.fixed(progressLeftLabel),
        this.progressRightLabelArg = Arg.fixed(progressRightLabel),
        this.performanceLabelArg = Arg.fixed(performanceLabel),
        this.performanceValueArg = Arg.fixed(performanceValue),
        this.metricsArg = Arg.fixed(metrics),
        this.onPickEpochArg = Arg.fixed(onPickEpoch),
        this.maxEpochArg = Arg.fixed(maxEpoch),
        this.selectedEpochArg = Arg.fixed(selectedEpoch),
        this.epochScoreLookupArg =
            epochScoreLookup == null ? null : Arg.fixed(epochScoreLookup),
        this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap);

  final Arg<Key?>? keyArg;

  final Arg<String> epochLabelArg;

  final Arg<double> progressArg;

  final Arg<String> progressLeftLabelArg;

  final Arg<String> progressRightLabelArg;

  final Arg<String> performanceLabelArg;

  final Arg<String> performanceValueArg;

  final Arg<List<EpochMetricData>> metricsArg;

  final Arg<void Function(int)> onPickEpochArg;

  final Arg<int> maxEpochArg;

  final Arg<int> selectedEpochArg;

  final Arg<String Function(int)?>? epochScoreLookupArg;

  final Arg<void Function()?>? onBackTapArg;

  Key? get key => keyArg?.value;

  String get epochLabel => epochLabelArg.value;

  double get progress => progressArg.value;

  String get progressLeftLabel => progressLeftLabelArg.value;

  String get progressRightLabel => progressRightLabelArg.value;

  String get performanceLabel => performanceLabelArg.value;

  String get performanceValue => performanceValueArg.value;

  List<EpochMetricData> get metrics => metricsArg.value;

  void Function(int) get onPickEpoch => onPickEpochArg.value;

  int get maxEpoch => maxEpochArg.value;

  int get selectedEpoch => selectedEpochArg.value;

  String Function(int)? get epochScoreLookup => epochScoreLookupArg?.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        epochLabelArg,
        progressArg,
        progressLeftLabelArg,
        progressRightLabelArg,
        performanceLabelArg,
        performanceValueArg,
        metricsArg,
        onPickEpochArg,
        maxEpochArg,
        selectedEpochArg,
        epochScoreLookupArg,
        onBackTapArg,
      ];
}
