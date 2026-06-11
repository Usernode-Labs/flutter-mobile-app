// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'challenge_reward_card.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component = Component<ChallengeRewardCard, ChallengeRewardCardArgs>;
typedef _Scenario = ChallengeRewardCardScenario;
typedef _Defaults = ChallengeRewardCardDefaults;
typedef _Story = ChallengeRewardCardStory;
typedef _Args = ChallengeRewardCardArgs;
final ChallengeRewardCardComponent =
    Component<ChallengeRewardCard, ChallengeRewardCardArgs>(
  name: meta.name ?? 'ChallengeRewardCard',
  path: meta.path ?? 'stories',
  docsBuilder: meta.docsBuilder,
  docComment:
      r'''A category-colored reward card displaying points earned for a challenge.

The card layout depends on [data]:
- [SimpleRewardData]: "Earned" label + total points only.
- [ProduceBlocksRewardData]: "Total Earned" label, progress bar, calculation
  row, and rank reward row.

Both variants share the optional epoch section at the bottom (controlled by
[epochEarned] null-check).''',
  stories: [
    $Simple..$generatedName = 'Simple',
    $ProduceBlocks..$generatedName = 'ProduceBlocks',
    $Community..$generatedName = 'Community',
  ],
);
typedef ChallengeRewardCardScenario
    = Scenario<ChallengeRewardCard, ChallengeRewardCardArgs>;
typedef ChallengeRewardCardDefaults
    = Defaults<ChallengeRewardCard, ChallengeRewardCardArgs>;

class ChallengeRewardCardStory
    extends Story<ChallengeRewardCard, ChallengeRewardCardArgs> {
  ChallengeRewardCardStory({
    super.name,
    super.setup,
    super.modes,
    required super.args,
    StoryWidgetBuilder<ChallengeRewardCard, ChallengeRewardCardArgs>? builder,
    super.scenarios,
  }) : super(
          builder: builder ??
              (context, args) => ChallengeRewardCard(
                    key: args.key,
                    category: args.category,
                    totalEarned: args.totalEarned,
                    data: args.data,
                    epochSectionLabel: args.epochSectionLabel,
                    epochEarned: args.epochEarned,
                    epochLabel: args.epochLabel,
                    onEpochTap: args.onEpochTap,
                  ),
        );
}

class ChallengeRewardCardArgs extends StoryArgs<ChallengeRewardCard> {
  ChallengeRewardCardArgs({
    Arg<Key?>? key,
    Arg<ChallengeCategory>? category,
    Arg<String>? totalEarned,
    required Arg<ChallengeRewardData> data,
    Arg<String?>? epochSectionLabel,
    Arg<String?>? epochEarned,
    Arg<String?>? epochLabel,
    Arg<void Function()?>? onEpochTap,
  })  : this.keyArg = $initArg('key', key, null),
        this.categoryArg = $initArg(
          'category',
          category,
          EnumArg<ChallengeCategory>(
            ChallengeCategory.technical,
            values: ChallengeCategory.values,
          ),
        )!,
        this.totalEarnedArg = $initArg(
          'totalEarned',
          totalEarned,
          StringArg(''),
        )!,
        this.dataArg = $initArg('data', data, null)!,
        this.epochSectionLabelArg = $initArg(
          'epochSectionLabel',
          epochSectionLabel,
          NullableStringArg(null),
        )!,
        this.epochEarnedArg = $initArg(
          'epochEarned',
          epochEarned,
          NullableStringArg(null),
        )!,
        this.epochLabelArg = $initArg(
          'epochLabel',
          epochLabel,
          NullableStringArg(null),
        )!,
        this.onEpochTapArg = $initArg('onEpochTap', onEpochTap, null);

  ChallengeRewardCardArgs.fixed({
    Key? key,
    ChallengeCategory category = ChallengeCategory.technical,
    String totalEarned = '',
    required ChallengeRewardData data,
    String? epochSectionLabel = null,
    String? epochEarned = null,
    String? epochLabel = null,
    void Function()? onEpochTap,
  })  : this.keyArg = key == null ? null : Arg.fixed(key),
        this.categoryArg = Arg.fixed(category),
        this.totalEarnedArg = Arg.fixed(totalEarned),
        this.dataArg = Arg.fixed(data),
        this.epochSectionLabelArg =
            epochSectionLabel == null ? null : Arg.fixed(epochSectionLabel),
        this.epochEarnedArg =
            epochEarned == null ? null : Arg.fixed(epochEarned),
        this.epochLabelArg = epochLabel == null ? null : Arg.fixed(epochLabel),
        this.onEpochTapArg = onEpochTap == null ? null : Arg.fixed(onEpochTap);

  final Arg<Key?>? keyArg;

  final Arg<ChallengeCategory> categoryArg;

  final Arg<String> totalEarnedArg;

  final Arg<ChallengeRewardData> dataArg;

  final Arg<String?>? epochSectionLabelArg;

  final Arg<String?>? epochEarnedArg;

  final Arg<String?>? epochLabelArg;

  final Arg<void Function()?>? onEpochTapArg;

  Key? get key => keyArg?.value;

  ChallengeCategory get category => categoryArg.value;

  String get totalEarned => totalEarnedArg.value;

  ChallengeRewardData get data => dataArg.value;

  String? get epochSectionLabel => epochSectionLabelArg?.value;

  String? get epochEarned => epochEarnedArg?.value;

  String? get epochLabel => epochLabelArg?.value;

  void Function()? get onEpochTap => onEpochTapArg?.value;

  @override
  List<Arg?> get list => [
        keyArg,
        categoryArg,
        totalEarnedArg,
        dataArg,
        epochSectionLabelArg,
        epochEarnedArg,
        epochLabelArg,
        onEpochTapArg,
      ];
}
