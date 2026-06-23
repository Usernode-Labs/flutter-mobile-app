// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'premium_challenge_contract_matrix.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<
      PremiumChallengeContractMatrix,
      PremiumChallengeContractMatrixArgs
    >;
typedef _Scenario = PremiumChallengeContractMatrixScenario;
typedef _Defaults = PremiumChallengeContractMatrixDefaults;
typedef _Story = PremiumChallengeContractMatrixStory;
typedef _Args = PremiumChallengeContractMatrixArgs;
final PremiumChallengeContractMatrixComponent =
    Component<
      PremiumChallengeContractMatrix,
      PremiumChallengeContractMatrixArgs
    >(
      name: meta.name ?? 'PremiumChallengeContractMatrix',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Premium/featured rendering matrix built from raw mobile API response shapes.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef PremiumChallengeContractMatrixScenario =
    Scenario<
      PremiumChallengeContractMatrix,
      PremiumChallengeContractMatrixArgs
    >;
typedef PremiumChallengeContractMatrixDefaults =
    Defaults<
      PremiumChallengeContractMatrix,
      PremiumChallengeContractMatrixArgs
    >;

class PremiumChallengeContractMatrixStory
    extends
        Story<
          PremiumChallengeContractMatrix,
          PremiumChallengeContractMatrixArgs
        > {
  PremiumChallengeContractMatrixStory({
    super.name,
    super.setup,
    super.modes,
    PremiumChallengeContractMatrixArgs? args,
    StoryWidgetBuilder<
      PremiumChallengeContractMatrix,
      PremiumChallengeContractMatrixArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? PremiumChallengeContractMatrixArgs(),
         builder:
             builder ??
             (context, args) => PremiumChallengeContractMatrix(key: args.key),
       );
}

class PremiumChallengeContractMatrixArgs
    extends StoryArgs<PremiumChallengeContractMatrix> {
  PremiumChallengeContractMatrixArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  PremiumChallengeContractMatrixArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
