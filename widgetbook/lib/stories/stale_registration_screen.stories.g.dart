// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'stale_registration_screen.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<FullPageErrorState, FullPageErrorStateArgs>;
typedef _Scenario = FullPageErrorStateScenario;
typedef _Defaults = FullPageErrorStateDefaults;
typedef _Story = FullPageErrorStateStory;
typedef _Args = FullPageErrorStateArgs;
final FullPageErrorStateComponent =
    Component<FullPageErrorState, FullPageErrorStateArgs>(
      name: meta.name ?? 'FullPageErrorState',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: r'''A centered error display for use as a full-page body.

Shows a prominent error icon inside a colored circle, a primary message,
an optional detail line, and an optional retry button.

Presentation-only — takes all state via constructor params.''',
      stories: [
        $Default..$generatedName = 'Default',
        $NoRetry..$generatedName = 'NoRetry',
        $MinimalError..$generatedName = 'MinimalError',
      ],
    );
typedef FullPageErrorStateScenario =
    Scenario<FullPageErrorState, FullPageErrorStateArgs>;
typedef FullPageErrorStateDefaults =
    Defaults<FullPageErrorState, FullPageErrorStateArgs>;

class FullPageErrorStateStory
    extends Story<FullPageErrorState, FullPageErrorStateArgs> {
  FullPageErrorStateStory({
    super.name,
    super.setup,
    super.modes,
    FullPageErrorStateArgs? args,
    StoryWidgetBuilder<FullPageErrorState, FullPageErrorStateArgs>? builder,
    super.scenarios,
  }) : super(
         args: args ?? FullPageErrorStateArgs(),
         builder:
             builder ??
             (context, args) => FullPageErrorState(
               key: args.key,
               message: args.message,
               detail: args.detail,
               onRetry: args.onRetry,
               retryLabel: args.retryLabel,
             ),
       );
}

class FullPageErrorStateArgs extends StoryArgs<FullPageErrorState> {
  FullPageErrorStateArgs({
    Arg<Key?>? key,
    Arg<String>? message,
    Arg<String?>? detail,
    Arg<void Function()?>? onRetry,
    Arg<String>? retryLabel,
  }) : this.keyArg = $initArg('key', key, null),
       this.messageArg = $initArg('message', message, StringArg(''))!,
       this.detailArg = $initArg('detail', detail, NullableStringArg(null))!,
       this.onRetryArg = $initArg('onRetry', onRetry, null),
       this.retryLabelArg = $initArg(
         'retryLabel',
         retryLabel,
         StringArg('Retry'),
       )!;

  FullPageErrorStateArgs.fixed({
    Key? key,
    String message = '',
    String? detail = null,
    void Function()? onRetry,
    String retryLabel = 'Retry',
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.messageArg = Arg.fixed(message),
       this.detailArg = detail == null ? null : Arg.fixed(detail),
       this.onRetryArg = onRetry == null ? null : Arg.fixed(onRetry),
       this.retryLabelArg = Arg.fixed(retryLabel);

  final Arg<Key?>? keyArg;

  final Arg<String> messageArg;

  final Arg<String?>? detailArg;

  final Arg<void Function()?>? onRetryArg;

  final Arg<String> retryLabelArg;

  Key? get key => keyArg?.value;

  String get message => messageArg.value;

  String? get detail => detailArg?.value;

  void Function()? get onRetry => onRetryArg?.value;

  String get retryLabel => retryLabelArg.value;

  @override
  List<Arg?> get list => [
    keyArg,
    messageArg,
    detailArg,
    onRetryArg,
    retryLabelArg,
  ];
}
