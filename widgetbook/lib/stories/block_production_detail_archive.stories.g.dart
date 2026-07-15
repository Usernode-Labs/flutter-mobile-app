// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'block_production_detail_archive.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<
      ArchivedBlockProductionDetailPrototype,
      ArchivedBlockProductionDetailPrototypeArgs
    >;
typedef _Scenario = ArchivedBlockProductionDetailPrototypeScenario;
typedef _Defaults = ArchivedBlockProductionDetailPrototypeDefaults;
typedef _Story = ArchivedBlockProductionDetailPrototypeStory;
typedef _Args = ArchivedBlockProductionDetailPrototypeArgs;
final ArchivedBlockProductionDetailPrototypeComponent =
    Component<
      ArchivedBlockProductionDetailPrototype,
      ArchivedBlockProductionDetailPrototypeArgs
    >(
      name: meta.name ?? 'ArchivedBlockProductionDetailPrototype',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment: null,
      stories: [
        $Jun23RichAtomicPrototype..$generatedName = 'Jun23RichAtomicPrototype',
      ],
    );
typedef ArchivedBlockProductionDetailPrototypeScenario =
    Scenario<
      ArchivedBlockProductionDetailPrototype,
      ArchivedBlockProductionDetailPrototypeArgs
    >;
typedef ArchivedBlockProductionDetailPrototypeDefaults =
    Defaults<
      ArchivedBlockProductionDetailPrototype,
      ArchivedBlockProductionDetailPrototypeArgs
    >;

class ArchivedBlockProductionDetailPrototypeStory
    extends
        Story<
          ArchivedBlockProductionDetailPrototype,
          ArchivedBlockProductionDetailPrototypeArgs
        > {
  ArchivedBlockProductionDetailPrototypeStory({
    super.name,
    super.setup,
    super.modes,
    ArchivedBlockProductionDetailPrototypeArgs? args,
    StoryWidgetBuilder<
      ArchivedBlockProductionDetailPrototype,
      ArchivedBlockProductionDetailPrototypeArgs
    >?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? ArchivedBlockProductionDetailPrototypeArgs(),
         builder:
             builder ??
             (context, args) =>
                 ArchivedBlockProductionDetailPrototype(key: args.key),
       );
}

class ArchivedBlockProductionDetailPrototypeArgs
    extends StoryArgs<ArchivedBlockProductionDetailPrototype> {
  ArchivedBlockProductionDetailPrototypeArgs({Arg<Key?>? key})
    : this.keyArg = $initArg('key', key, null);

  ArchivedBlockProductionDetailPrototypeArgs.fixed({Key? key})
    : this.keyArg = key == null ? null : Arg.fixed(key);

  final Arg<Key?>? keyArg;

  Key? get key => keyArg?.value;

  @override
  List<Arg?> get list => [keyArg];
}
