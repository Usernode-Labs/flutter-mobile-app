// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'result_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ResultPage, ResultPageArgs>;
typedef _Scenario = ResultPageScenario;
typedef _Defaults = ResultPageDefaults;
typedef _Story = ResultPageStory;
typedef _Args = ResultPageArgs;
final ResultPageComponent = Component<ResultPage, ResultPageArgs>(
  name: meta.name ?? 'ResultPage',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A full-page centered layout for displaying an outcome (success, failure,
or informational) with icon, title, optional subtitle, and action buttons.

Replaces hand-rolled transaction result screens with a consistent layout.

Presentation-only — takes all state via constructor params.''',
  stories: [
    $Success..$generatedName = 'Success',
    $Failure..$generatedName = 'Failure',
    $Info..$generatedName = 'Info',
    $Minimal..$generatedName = 'Minimal',
  ],
);
typedef ResultPageScenario = Scenario<ResultPage, ResultPageArgs>;
typedef ResultPageDefaults = Defaults<ResultPage, ResultPageArgs>;

class ResultPageStory extends Story<ResultPage, ResultPageArgs> {
  ResultPageStory({
    super.name,
    super.setup,
    super.modes,
    ResultPageArgs? args,
    StoryWidgetBuilder<ResultPage, ResultPageArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? ResultPageArgs(),
          builder: builder ??
              (context, args) => ResultPage(
                    key: args.key,
                    variant: args.variant,
                    icon: args.icon,
                    title: args.title,
                    subtitle: args.subtitle,
                    primaryAction: args.primaryAction,
                    secondaryAction: args.secondaryAction,
                  ),
        );
}

class ResultPageArgs extends StoryArgs<ResultPage> {
  ResultPageArgs({
    Arg<Key?>? key,
    Arg<ResultPageVariant>? variant,
    Arg<IconData?>? icon,
    Arg<String>? title,
    Arg<String?>? subtitle,
    Arg<Widget?>? primaryAction,
    Arg<Widget?>? secondaryAction,
  })  : this.keyArg = $initArg('key', key, null),
        this.variantArg = $initArg(
          'variant',
          variant,
          EnumArg<ResultPageVariant>(
            ResultPageVariant.success,
            values: ResultPageVariant.values,
          ),
        )!,
        this.iconArg = $initArg('icon', icon, null),
        this.titleArg = $initArg('title', title, StringArg(''))!,
        this.subtitleArg = $initArg(
          'subtitle',
          subtitle,
          NullableStringArg(null),
        )!,
        this.primaryActionArg = $initArg('primaryAction', primaryAction, null),
        this.secondaryActionArg = $initArg(
          'secondaryAction',
          secondaryAction,
          null,
        );

  ResultPageArgs.fixed({
    Key? key,
    ResultPageVariant variant = ResultPageVariant.success,
    IconData? icon,
    String title = '',
    String? subtitle = null,
    Widget? primaryAction,
    Widget? secondaryAction,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.variantArg = Arg.fixed(variant),
        this.iconArg = icon == null ? null : Arg.fixed(icon),
        this.titleArg = Arg.fixed(title),
        this.subtitleArg = subtitle == null ? null : Arg.fixed(subtitle),
        this.primaryActionArg =
            primaryAction == null ? null : Arg.fixed(primaryAction),
        this.secondaryActionArg =
            secondaryAction == null ? null : Arg.fixed(secondaryAction);

  final Arg<Key?>? keyArg;

  final Arg<ResultPageVariant> variantArg;

  final Arg<IconData?>? iconArg;

  final Arg<String> titleArg;

  final Arg<String?>? subtitleArg;

  final Arg<Widget?>? primaryActionArg;

  final Arg<Widget?>? secondaryActionArg;

  Key? get key => keyArg?.value;

  ResultPageVariant get variant => variantArg.value;

  IconData? get icon => iconArg?.value;

  String get title => titleArg.value;

  String? get subtitle => subtitleArg?.value;

  Widget? get primaryAction => primaryActionArg?.value;

  Widget? get secondaryAction => secondaryActionArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        variantArg,
        iconArg,
        titleArg,
        subtitleArg,
        primaryActionArg,
        secondaryActionArg,
      ];
}
