// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'settings_detail_page.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<SettingsDetailPage, SettingsDetailPageArgs>;
typedef _Scenario = SettingsDetailPageScenario;
typedef _Defaults = SettingsDetailPageDefaults;
typedef _Story = SettingsDetailPageStory;
typedef _Args = SettingsDetailPageArgs;
final SettingsDetailPageComponent =
    Component<SettingsDetailPage, SettingsDetailPageArgs>(
      name: meta.name ?? 'SettingsDetailPage',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $AllGood..$generatedName = 'AllGood',
        $ActionNeeded..$generatedName = 'ActionNeeded',
      ],
    );
typedef SettingsDetailPageScenario =
    Scenario<SettingsDetailPage, SettingsDetailPageArgs>;
typedef SettingsDetailPageDefaults =
    Defaults<SettingsDetailPage, SettingsDetailPageArgs>;

class SettingsDetailPageStory
    extends Story<SettingsDetailPage, SettingsDetailPageArgs> {
  SettingsDetailPageStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<SettingsDetailPage, SettingsDetailPageArgs>? builder,
    super.scenarios,
  }) : super(
         builder:
             builder ??
             (context, args) => SettingsDetailPage(
               key: args.key,
               title: args.title,
               status: args.status,
               sections: args.sections,
               onBackTap: args.onBackTap,
               onSettingsTap: args.onSettingsTap,
             ),
       );
}

class SettingsDetailPageArgs extends StoryArgs<SettingsDetailPage> {
  SettingsDetailPageArgs({
    Arg<Key?>? key,
    Arg<String>? title,
    required Arg<SettingsDetailStatusData> status,
    required Arg<List<SettingsDetailSectionData>> sections,
    Arg<void Function()?>? onBackTap,
    Arg<void Function()?>? onSettingsTap,
  }) : this.keyArg = $initArg('key', key, null),
       this.titleArg = $initArg('title', title, StringArg(''))!,
       this.statusArg = $initArg('status', status, null)!,
       this.sectionsArg = $initArg('sections', sections, null)!,
       this.onBackTapArg = $initArg('onBackTap', onBackTap, null),
       this.onSettingsTapArg = $initArg('onSettingsTap', onSettingsTap, null);

  SettingsDetailPageArgs.fixed({
    Key? key,
    String title = '',
    required SettingsDetailStatusData status,
    required List<SettingsDetailSectionData> sections,
    void Function()? onBackTap,
    void Function()? onSettingsTap,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.titleArg = Arg.fixed(title),
       this.statusArg = Arg.fixed(status),
       this.sectionsArg = Arg.fixed(sections),
       this.onBackTapArg = onBackTap == null ? null : Arg.fixed(onBackTap),
       this.onSettingsTapArg = onSettingsTap == null
           ? null
           : Arg.fixed(onSettingsTap);

  final Arg<Key?>? keyArg;

  final Arg<String> titleArg;

  final Arg<SettingsDetailStatusData> statusArg;

  final Arg<List<SettingsDetailSectionData>> sectionsArg;

  final Arg<void Function()?>? onBackTapArg;

  final Arg<void Function()?>? onSettingsTapArg;

  Key? get key => keyArg?.value;

  String get title => titleArg.value;

  SettingsDetailStatusData get status => statusArg.value;

  List<SettingsDetailSectionData> get sections => sectionsArg.value;

  void Function()? get onBackTap => onBackTapArg?.value;

  void Function()? get onSettingsTap => onSettingsTapArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    titleArg,
    statusArg,
    sectionsArg,
    onBackTapArg,
    onSettingsTapArg,
  ];
}
