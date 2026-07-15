// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_import, prefer_relative_imports, directives_ordering, unused_element, strict_raw_type

part of 'token_allocation_reveal.stories.dart';

// **************************************************************************
// StoryGenerator
// **************************************************************************

typedef _Component =
    Component<TokenAllocationReveal, TokenAllocationRevealArgs>;
typedef _Scenario = TokenAllocationRevealScenario;
typedef _Defaults = TokenAllocationRevealDefaults;
typedef _Story = TokenAllocationRevealStory;
typedef _Args = TokenAllocationRevealArgs;
final TokenAllocationRevealComponent =
    Component<TokenAllocationReveal, TokenAllocationRevealArgs>(
      name: meta.name ?? 'TokenAllocationReveal',
      path: meta.path ?? 'stories',
      docsBuilder: meta.docsBuilder,
      docComment:
          r'''A season token allocation card whose amount stays hidden until revealed.

Hidden state is quiet and achromatic with an explicit "Reveal" button.
Pressing it spends the color budget on a premium celebration: the surface
tints, pulse rings emanate from the amount, and the value scales in — a
small win moment.

Presentation-only: [amount] arrives formatted; [onReveal] lets the
feature layer persist that the user has seen the allocation. Pass
[revealed] as true to render the settled revealed state without the
celebration (e.g. on revisit).''',
      stories: [
        $Default..$generatedName = 'Default',
        $Revealed..$generatedName = 'Revealed',
      ],
    );
typedef TokenAllocationRevealScenario =
    Scenario<TokenAllocationReveal, TokenAllocationRevealArgs>;
typedef TokenAllocationRevealDefaults =
    Defaults<TokenAllocationReveal, TokenAllocationRevealArgs>;

class TokenAllocationRevealStory
    extends Story<TokenAllocationReveal, TokenAllocationRevealArgs> {
  TokenAllocationRevealStory({
    super.name,
    super.setup,
    super.modes,
    TokenAllocationRevealArgs? args,
    StoryWidgetBuilder<TokenAllocationReveal, TokenAllocationRevealArgs>?
    builder,
    super.scenarios,
  }) : super(
         args: args ?? TokenAllocationRevealArgs(),
         builder:
             builder ??
             (context, args) => TokenAllocationReveal(
               key: args.key,
               amount: args.amount,
               label: args.label,
               disclaimer: args.disclaimer,
               revealLabel: args.revealLabel,
               icon: args.icon,
               revealed: args.revealed,
               onReveal: args.onReveal,
             ),
       );
}

class TokenAllocationRevealArgs extends StoryArgs<TokenAllocationReveal> {
  TokenAllocationRevealArgs({
    Arg<Key?>? key,
    Arg<String>? amount,
    Arg<String>? label,
    Arg<String?>? disclaimer,
    Arg<String>? revealLabel,
    Arg<IconData>? icon,
    Arg<bool>? revealed,
    Arg<void Function()?>? onReveal,
  }) : this.keyArg = $initArg('key', key, null),
       this.amountArg = $initArg('amount', amount, StringArg(''))!,
       this.labelArg = $initArg('label', label, StringArg('Token Allocation'))!,
       this.disclaimerArg = $initArg(
         'disclaimer',
         disclaimer,
         NullableStringArg(null),
       )!,
       this.revealLabelArg = $initArg(
         'revealLabel',
         revealLabel,
         StringArg('Reveal'),
       )!,
       this.iconArg = $initArg('icon', icon, ConstArg(Symbols.redeem_sharp))!,
       this.revealedArg = $initArg('revealed', revealed, BoolArg(false))!,
       this.onRevealArg = $initArg('onReveal', onReveal, null);

  TokenAllocationRevealArgs.fixed({
    Key? key,
    String amount = '',
    String label = 'Token Allocation',
    String? disclaimer = null,
    String revealLabel = 'Reveal',
    IconData icon = Symbols.redeem_sharp,
    bool revealed = false,
    void Function()? onReveal,
  }) : this.keyArg = key == null ? null : Arg.fixed(key),
       this.amountArg = Arg.fixed(amount),
       this.labelArg = Arg.fixed(label),
       this.disclaimerArg = disclaimer == null ? null : Arg.fixed(disclaimer),
       this.revealLabelArg = Arg.fixed(revealLabel),
       this.iconArg = Arg.fixed(icon),
       this.revealedArg = Arg.fixed(revealed),
       this.onRevealArg = onReveal == null ? null : Arg.fixed(onReveal);

  final Arg<Key?>? keyArg;

  final Arg<String> amountArg;

  final Arg<String> labelArg;

  final Arg<String?>? disclaimerArg;

  final Arg<String> revealLabelArg;

  final Arg<IconData> iconArg;

  final Arg<bool> revealedArg;

  final Arg<void Function()?>? onRevealArg;

  Key? get key => keyArg?.value;

  String get amount => amountArg.value;

  String get label => labelArg.value;

  String? get disclaimer => disclaimerArg?.value;

  String get revealLabel => revealLabelArg.value;

  IconData get icon => iconArg.value;

  bool get revealed => revealedArg.value;

  void Function()? get onReveal => onRevealArg?.value;

  @override
  List<Arg?> get list => [
    keyArg,
    amountArg,
    labelArg,
    disclaimerArg,
    revealLabelArg,
    iconArg,
    revealedArg,
    onRevealArg,
  ];
}
