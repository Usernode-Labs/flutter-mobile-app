// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'stale_registration_screen.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component
    = Component<StaleRegistrationDemo, StaleRegistrationDemoArgs>;
typedef _Scenario = StaleRegistrationDemoScenario;
typedef _Defaults = StaleRegistrationDemoDefaults;
typedef _Story = StaleRegistrationDemoStory;
typedef _Args = StaleRegistrationDemoArgs;
final StaleRegistrationDemoComponent =
    Component<StaleRegistrationDemo, StaleRegistrationDemoArgs>(
  name: meta.name ?? 'StaleRegistrationDemo',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''Wrapper to give StaleRegistration stories a distinct component identity
from the generic FullPageErrorState stories.''',
  stories: [
    $Default..$generatedName = 'Default',
    $NoRetry..$generatedName = 'NoRetry',
    $MinimalError..$generatedName = 'MinimalError',
  ],
);
typedef StaleRegistrationDemoScenario
    = Scenario<StaleRegistrationDemo, StaleRegistrationDemoArgs>;
typedef StaleRegistrationDemoDefaults
    = Defaults<StaleRegistrationDemo, StaleRegistrationDemoArgs>;

class StaleRegistrationDemoStory
    extends Story<StaleRegistrationDemo, StaleRegistrationDemoArgs> {
  StaleRegistrationDemoStory({
    super.name,
    super.setup,
    super.modes,
    StaleRegistrationDemoArgs? args,
    StoryWidgetBuilder<StaleRegistrationDemo, StaleRegistrationDemoArgs>?
        builder,
    super.scenarios,
  }) : super(
          args: args ?? StaleRegistrationDemoArgs(),
          builder: builder ??
              (context, args) => StaleRegistrationDemo(
                    key: args.key,
                    message: args.message,
                    detail: args.detail,
                    onRetry: args.onRetry,
                    retryLabel: args.retryLabel,
                  ),
        );
}

class StaleRegistrationDemoArgs extends StoryArgs<StaleRegistrationDemo> {
  StaleRegistrationDemoArgs({
    Arg<Key?>? key,
    Arg<String>? message,
    Arg<String?>? detail,
    Arg<void Function()?>? onRetry,
    Arg<String>? retryLabel,
  })  : this.keyArg = $initArg('key', key, null),
        this.messageArg = $initArg('message', message, StringArg(''))!,
        this.detailArg = $initArg('detail', detail, NullableStringArg(null))!,
        this.onRetryArg = $initArg('onRetry', onRetry, null),
        this.retryLabelArg = $initArg(
          'retryLabel',
          retryLabel,
          StringArg('Retry'),
        )!;

  StaleRegistrationDemoArgs.fixed({
    Key? key,
    String message = '',
    String? detail = null,
    void Function()? onRetry,
    String retryLabel = 'Retry',
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
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
