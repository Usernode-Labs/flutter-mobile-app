// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'api_challenge_contract_matrix.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<ApiChallengeContractMatrix, ApiChallengeContractMatrixArgs>;
typedef _Scenario = ApiChallengeContractMatrixScenario;
typedef _Defaults = ApiChallengeContractMatrixDefaults;
typedef _Story = ApiChallengeContractMatrixStory;
typedef _Args = ApiChallengeContractMatrixArgs;
final ApiChallengeContractMatrixComponent =
    Component<ApiChallengeContractMatrix, ApiChallengeContractMatrixArgs>(
      name: meta.name ?? 'ApiChallengeContractMatrix',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''Visual contract matrix built from raw current mobile API response shapes.''',
      stories: [$Default..$generatedName = 'Default'],
    );
typedef ApiChallengeContractMatrixScenario =
    Scenario<ApiChallengeContractMatrix, ApiChallengeContractMatrixArgs>;
typedef ApiChallengeContractMatrixDefaults =
    Defaults<ApiChallengeContractMatrix, ApiChallengeContractMatrixArgs>;

class ApiChallengeContractMatrixStory
    extends Story<ApiChallengeContractMatrix, ApiChallengeContractMatrixArgs> {
  ApiChallengeContractMatrixStory({
    super.name,
    super.setup,
    super.modes,
    ApiChallengeContractMatrixArgs? args,
    StoryWidgetBuilder<
      ApiChallengeContractMatrix,
      ApiChallengeContractMatrixArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? ApiChallengeContractMatrixArgs(),
         builder:
             builder ??
             (context, args) => ApiChallengeContractMatrix(key: args.key),
       );
}

class ApiChallengeContractMatrixArgs
    extends StoryArgs<ApiChallengeContractMatrix> {
  ApiChallengeContractMatrixArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  ApiChallengeContractMatrixArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
