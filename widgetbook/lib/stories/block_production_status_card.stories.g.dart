// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'block_production_status_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<BlockProductionStatusCard, BlockProductionStatusCardArgs>;
typedef _Scenario = BlockProductionStatusCardScenario;
typedef _Defaults = BlockProductionStatusCardDefaults;
typedef _Story = BlockProductionStatusCardStory;
typedef _Args = BlockProductionStatusCardArgs;
final BlockProductionStatusCardComponent =
    Component<BlockProductionStatusCard, BlockProductionStatusCardArgs>(
      name: meta.name ?? 'BlockProductionStatusCard',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A card showing 4 [ListTile] rows for block production pipeline readiness.

Presentation-only — takes all state via constructor params.''',
      stories: [
        $Default..$generatedName = 'Default',
        $WithMissedBlocks..$generatedName = 'WithMissedBlocks',
      ],
    );
typedef BlockProductionStatusCardScenario =
    Scenario<BlockProductionStatusCard, BlockProductionStatusCardArgs>;
typedef BlockProductionStatusCardDefaults =
    Defaults<BlockProductionStatusCard, BlockProductionStatusCardArgs>;

class BlockProductionStatusCardStory
    extends Story<BlockProductionStatusCard, BlockProductionStatusCardArgs> {
  BlockProductionStatusCardStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<
      BlockProductionStatusCard,
      BlockProductionStatusCardArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) =>
                 BlockProductionStatusCard(key: args.key, data: args.data),
       );
}

class BlockProductionStatusCardArgs
    extends StoryArgs<BlockProductionStatusCard> {
  BlockProductionStatusCardArgs({
    Arg<Key?>? key,
    required Arg<BlockProductionStatusData> data,
  }) : this.keyArg = $initArg('key', key, null),
       this.dataArg = $initArg('data', data, null)!;

  BlockProductionStatusCardArgs.fixed({
    Key? key,
    required BlockProductionStatusData data,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.dataArg = Arg.fixed(data);

  final Arg<Key?>? keyArg;

  final Arg<BlockProductionStatusData> dataArg;

  Key? get key => keyArg?.value;

  BlockProductionStatusData get data => dataArg.value;

  @override
  List<Arg?> get list => [keyArg, dataArg];
}
