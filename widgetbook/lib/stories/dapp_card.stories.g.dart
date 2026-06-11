// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'dapp_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<DappCard, DappCardArgs>;
typedef _Scenario = DappCardScenario;
typedef _Defaults = DappCardDefaults;
typedef _Story = DappCardStory;
typedef _Args = DappCardArgs;
final DappCardComponent = Component<DappCard, DappCardArgs>(
  name: meta.name ?? 'DappCard',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment: null,
  stories: [
    $Default..$generatedName = 'Default',
    $Disabled..$generatedName = 'Disabled',
    $NoStats..$generatedName = 'NoStats',
  ],
);
typedef DappCardScenario = Scenario<DappCard, DappCardArgs>;
typedef DappCardDefaults = Defaults<DappCard, DappCardArgs>;

class DappCardStory extends Story<DappCard, DappCardArgs> {
  DappCardStory({
    super.name,
    super.setup,
    super.modes,
    DappCardArgs? args,
    StoryWidgetBuilder<DappCard, DappCardArgs>? builder,
    super.scenarios,
  }) : super(
          args: args ?? DappCardArgs(),
          builder: builder ??
              (context, args) => DappCard(
                    key: args.key,
                    name: args.name,
                    author: args.author,
                    description: args.description,
                    users: args.users,
                    txns: args.txns,
                    onTap: args.onTap,
                    enabled: args.enabled,
                    disabledLabel: args.disabledLabel,
                  ),
        );
}

class DappCardArgs extends StoryArgs<DappCard> {
  DappCardArgs({
    Arg<Key?>? key,
    Arg<String>? name,
    Arg<String>? author,
    Arg<String>? description,
    Arg<int?>? users,
    Arg<int?>? txns,
    Arg<void Function()?>? onTap,
    Arg<bool>? enabled,
    Arg<String?>? disabledLabel,
  })  : this.keyArg = $initArg('key', key, null),
        this.nameArg = $initArg('name', name, StringArg(''))!,
        this.authorArg = $initArg('author', author, StringArg(''))!,
        this.descriptionArg = $initArg(
          'description',
          description,
          StringArg(DappCard.kDefaultDescription),
        )!,
        this.usersArg = $initArg('users', users, NullableIntArg(null))!,
        this.txnsArg = $initArg('txns', txns, NullableIntArg(null))!,
        this.onTapArg = $initArg('onTap', onTap, null),
        this.enabledArg = $initArg('enabled', enabled, BoolArg(true))!,
        this.disabledLabelArg = $initArg(
          'disabledLabel',
          disabledLabel,
          NullableStringArg(null),
        )!;

  DappCardArgs.fixed({
    Key? key,
    String name = '',
    String author = '',
    String description = DappCard.kDefaultDescription,
    int? users = null,
    int? txns = null,
    void Function()? onTap,
    bool enabled = true,
    String? disabledLabel = null,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.nameArg = Arg.fixed(name),
        this.authorArg = Arg.fixed(author),
        this.descriptionArg = Arg.fixed(description),
        this.usersArg = users == null ? null : Arg.fixed(users),
        this.txnsArg = txns == null ? null : Arg.fixed(txns),
        this.onTapArg = onTap == null ? null : Arg.fixed(onTap),
        this.enabledArg = Arg.fixed(enabled),
        this.disabledLabelArg =
            disabledLabel == null ? null : Arg.fixed(disabledLabel);

  final Arg<Key?>? keyArg;

  final Arg<String> nameArg;

  final Arg<String> authorArg;

  final Arg<String> descriptionArg;

  final Arg<int?>? usersArg;

  final Arg<int?>? txnsArg;

  final Arg<void Function()?>? onTapArg;

  final Arg<bool> enabledArg;

  final Arg<String?>? disabledLabelArg;

  Key? get key => keyArg?.value;

  String get name => nameArg.value;

  String get author => authorArg.value;

  String get description => descriptionArg.value;

  int? get users => usersArg?.value;

  int? get txns => txnsArg?.value;

  void Function()? get onTap => onTapArg?.value;

  bool get enabled => enabledArg.value;

  String? get disabledLabel => disabledLabelArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        nameArg,
        authorArg,
        descriptionArg,
        usersArg,
        txnsArg,
        onTapArg,
        enabledArg,
        disabledLabelArg,
      ];
}
