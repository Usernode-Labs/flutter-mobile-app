// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'node_sync_detail_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<NodeSyncDetailPage, NodeSyncDetailPageArgs>;
typedef _Scenario = NodeSyncDetailPageScenario;
typedef _Defaults = NodeSyncDetailPageDefaults;
typedef _Story = NodeSyncDetailPageStory;
typedef _Args = NodeSyncDetailPageArgs;
final NodeSyncDetailPageComponent =
    Component<NodeSyncDetailPage, NodeSyncDetailPageArgs>(
      name: meta.name ?? 'NodeSyncDetailPage',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $Syncing..$generatedName = 'Syncing',
        $Synced..$generatedName = 'Synced',
      ],
    );
typedef NodeSyncDetailPageScenario =
    Scenario<NodeSyncDetailPage, NodeSyncDetailPageArgs>;
typedef NodeSyncDetailPageDefaults =
    Defaults<NodeSyncDetailPage, NodeSyncDetailPageArgs>;

class NodeSyncDetailPageStory
    extends Story<NodeSyncDetailPage, NodeSyncDetailPageArgs> {
  NodeSyncDetailPageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<NodeSyncDetailPage, NodeSyncDetailPageArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => NodeSyncDetailPage(
               key: args.key,
               title: args.title,
               overview: args.overview,
               progress: args.progress,
               sections: args.sections,
               onBackTap: args.onBackTap,
               onSettingsTap: args.onSettingsTap,
               onCopyChainTap: args.onCopyChainTap,
             ),
       );
}

class NodeSyncDetailPageArgs extends StoryArgs<NodeSyncDetailPage> {
  NodeSyncDetailPageArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    required Arg<NodeSyncOverviewData> overview,
    required Arg<NodeSyncProgressData> progress,
    required Arg<List<NodeSyncDetailSectionData>> sections,
    Arg<void Function()?>? onBackTap,
    Arg<void Function()?>? onSettingsTap,
    Arg<void Function()?>? onCopyChainTap,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.overviewArg = $initArg('overview', overview, null)!,
       this.progressArg = $initArg('progress', progress, null)!,
       this.sectionsArg = $initArg('sections', sections, null)!,
       this.onBackTapArg = $initArg('onBackTap', onBackTap, null),
       this.onSettingsTapArg = $initArg('onSettingsTap', onSettingsTap, null),
       this.onCopyChainTapArg = $initArg(
         'onCopyChainTap',
         onCopyChainTap,
         null,
       );

  NodeSyncDetailPageArgs.fixed({
    Key? key,
    String title = '',
    required NodeSyncOverviewData overview,
    required NodeSyncProgressData progress,
    required List<NodeSyncDetailSectionData> sections,
    void Function()? onBackTap,
    void Function()? onSettingsTap,
    void Function()? onCopyChainTap,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.overviewArg = Arg.fixed(overview),
       this.progressArg = Arg.fixed(progress),
       this.sectionsArg = Arg.fixed(sections),
       this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap),
       this.onSettingsTapArg = onSettingsTap == null
           ? null
           : Arg.fixed(onSettingsTap),
       this.onCopyChainTapArg = onCopyChainTap == null
           ? null
           : Arg.fixed(onCopyChainTap);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<NodeSyncOverviewData> overviewArg;

  final Arg<NodeSyncProgressData> progressArg;

  final Arg<List<NodeSyncDetailSectionData>> sectionsArg;

  final Arg<void Function()?>? onBackTapArg;

  final Arg<void Function()?>? onSettingsTapArg;

  final Arg<void Function()?>? onCopyChainTapArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  NodeSyncOverviewData get overview => overviewArg.value;

  NodeSyncProgressData get progress => progressArg.value;

  List<NodeSyncDetailSectionData> get sections => sectionsArg.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  void Function()? get onSettingsTap => onSettingsTapArg?.value;

  void Function()? get onCopyChainTap => onCopyChainTapArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    overviewArg,
    progressArg,
    sectionsArg,
    onBackTapArg,
    onSettingsTapArg,
    onCopyChainTapArg,
  ];
}
