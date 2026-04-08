// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'zk_identity_status_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ZkIdentityStatusCard, ZkIdentityStatusCardArgs>;
typedef _Scenario = ZkIdentityStatusCardScenario;
typedef _Defaults = ZkIdentityStatusCardDefaults;
typedef _Story = ZkIdentityStatusCardStory;
typedef _Args = ZkIdentityStatusCardArgs;
final ZkIdentityStatusCardComponent =
    Component<ZkIdentityStatusCard, ZkIdentityStatusCardArgs>(
      name: meta.name ?? 'ZkIdentityStatusCard',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A card showing proof detail rows as [ListTile]s with [IconBadge] leading.

Follows the same pattern as [BlockProductionStatusCard]:
[AppCard] → [Column] of [ListTile] rows.

Presentation-only — takes all state via constructor params.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ZkIdentityStatusCardScenario =
    Scenario<ZkIdentityStatusCard, ZkIdentityStatusCardArgs>;
typedef ZkIdentityStatusCardDefaults =
    Defaults<ZkIdentityStatusCard, ZkIdentityStatusCardArgs>;

class ZkIdentityStatusCardStory
    extends Story<ZkIdentityStatusCard, ZkIdentityStatusCardArgs> {
  ZkIdentityStatusCardStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ZkIdentityStatusCard, ZkIdentityStatusCardArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) =>
                 ZkIdentityStatusCard(key: args.key, data: args.data),
       );
}

class ZkIdentityStatusCardArgs extends StoryArgs<ZkIdentityStatusCard> {
  ZkIdentityStatusCardArgs({
    Arg<Key?>? key,
    required Arg<ZkIdentityStatusData> data,
  }) : this.keyArg = $initArg('key', key, null),
       this.dataArg = $initArg('data', data, null)!;

  ZkIdentityStatusCardArgs.fixed({Key? key, required ZkIdentityStatusData data})
    : this.keyArg = key == null ? null : Arg.fixed(key),
      this.dataArg = Arg.fixed(data);

  final Arg<Key?>? keyArg;

  final Arg<ZkIdentityStatusData> dataArg;

  Key? get key => keyArg?.value;

  ZkIdentityStatusData get data => dataArg.value;

  @override
  List<Arg?> get list => [keyArg, dataArg];
}
