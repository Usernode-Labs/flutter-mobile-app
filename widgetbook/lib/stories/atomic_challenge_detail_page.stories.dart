import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'atomic_challenge_detail_page.stories.g.dart';

const meta =
    MetaWithArgs<AtomicChallengeDetailPage, AtomicChallengeDetailInput>(
      path: 'prototypes/challenges',
    );

class AtomicChallengeDetailInput {
  const AtomicChallengeDetailInput({
    this.title = 'Propose an app change',
    this.description =
        'Improve an existing dApp and help test the new application layer.',
    this.leftText = 'Not done',
    this.rightText = '500 pts',
    this.progressHelperText,
    this.phase = AtomicChallengePhase.open,
    this.fill = 0,
    this.dateText = 'Jun 4 - Jun 17',
    this.pointsLogic = 'Earn 500 pts when your proposed change is accepted.',
    this.ctaLabel = 'Join the challenge',
    this.rules,
    this.heroCard,
    this.railTreatment = AtomicChallengeRailTreatment.checkbox,
  });

  final String title;
  final String description;
  final String leftText;
  final String rightText;
  final String? progressHelperText;
  final AtomicChallengePhase phase;
  final double? fill;
  final String dateText;
  final String pointsLogic;
  final String ctaLabel;
  final String? rules;
  final AtomicChallengeTechnicalHeroCardData? heroCard;
  final AtomicChallengeRailTreatment railTreatment;
}

final defaults = _Defaults(
  builder: (context, args) {
    return AtomicChallengeDetailPage(
      title: args.title,
      description: args.description,
      leftText: args.leftText,
      rightText: args.rightText,
      progressHelperText: args.progressHelperText,
      phase: args.phase,
      fill: args.fill,
      dateText: args.dateText,
      pointsLogic: args.pointsLogic,
      ctaLabel: args.ctaLabel,
      rules: args.rules,
      heroCard: args.heroCard,
      railTreatment: args.railTreatment,
      onBackTap: () {},
      onCtaTap: () {},
    );
  },
  setup: (context, child, args) {
    return SizedBox(width: 390, height: 844, child: child);
  },
);

_Args _detailArgs({
  required String title,
  required String description,
  required String leftText,
  required String rightText,
  String? progressHelperText,
  required AtomicChallengePhase phase,
  required double? fill,
  required String dateText,
  required String pointsLogic,
  String ctaLabel = 'Join the challenge',
  String? rules,
  AtomicChallengeTechnicalHeroCardData? heroCard,
  AtomicChallengeRailTreatment railTreatment =
      AtomicChallengeRailTreatment.standard,
}) {
  return _Args.fixed(
    title: title,
    description: description,
    leftText: leftText,
    rightText: rightText,
    progressHelperText: progressHelperText,
    phase: phase,
    fill: fill,
    dateText: dateText,
    pointsLogic: pointsLogic,
    ctaLabel: ctaLabel,
    rules: rules,
    heroCard: heroCard,
    railTreatment: railTreatment,
  );
}

final _blockProductionHeroCard = AtomicChallengeTechnicalHeroCardData(
  totalEarned: '10,550',
  formula: const AtomicChallengeHeroFormula(
    rateLabel: 'Success rate',
    rateValue: '90%',
    maxLabel: 'Assigned slots',
    maxValue: '5,000',
    totalLabel: 'Base reward',
    totalValue: '9,050',
  ),
  rewardLines: const [
    AtomicChallengeHeroRewardLine(
      label: 'Top 3 rank reward',
      badge: '2nd',
      value: '+1,500',
    ),
    AtomicChallengeHeroRewardLine(label: 'Last 24h', value: '+250'),
    AtomicChallengeHeroRewardLine(label: 'First block reward', value: '+250'),
  ],
  epochLabel: 'View epoch 12 slots',
  onEpochTap: _noop,
  overview: const [
    AtomicChallengeHeroOverviewItem(
      label: 'Network',
      value: 'Connected',
      icon: Symbols.wifi_sharp,
      tone: AtomicChallengeHeroOverviewTone.success,
    ),
    AtomicChallengeHeroOverviewItem(
      label: 'VRF Calculation',
      value: 'Complete',
      icon: Symbols.casino_sharp,
      tone: AtomicChallengeHeroOverviewTone.success,
    ),
    AtomicChallengeHeroOverviewItem(
      label: 'Next Block',
      value: 'in ~12 min',
      icon: Symbols.schedule_sharp,
      tone: AtomicChallengeHeroOverviewTone.info,
    ),
    AtomicChallengeHeroOverviewItem(
      label: 'Last Produced',
      value: '2 min ago',
      icon: Symbols.check_circle_sharp,
      tone: AtomicChallengeHeroOverviewTone.success,
    ),
    AtomicChallengeHeroOverviewItem(
      label: 'Missed Blocks',
      value: 'None',
      icon: Symbols.disabled_by_default_sharp,
      tone: AtomicChallengeHeroOverviewTone.success,
    ),
  ],
);

void _noop() {}

final $ExpandedAtomic = _Story(
  name: 'Expanded atomic',
  args: _Args(
    title: StringArg('Propose an app change'),
    description: StringArg(
      'Improve an existing dApp and help test the new application layer.',
    ),
    leftText: StringArg('Not done'),
    rightText: StringArg('500 pts'),
    progressHelperText: NullableStringArg(null),
    phase: EnumArg(
      AtomicChallengePhase.open,
      values: AtomicChallengePhase.values,
    ),
    fill: NullableDoubleArg(
      0,
      style: const SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    dateText: StringArg('Jun 4 - Jun 17'),
    pointsLogic: StringArg(
      'Earn 500 pts when your proposed change is accepted.',
    ),
    ctaLabel: StringArg('Join the challenge'),
    rules: NullableStringArg(null),
    railTreatment: EnumArg(
      AtomicChallengeRailTreatment.checkbox,
      values: AtomicChallengeRailTreatment.values,
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'One step open',
      args: _detailArgs(
        title: 'Propose an app change',
        description:
            'Improve an existing dApp and help test the new application layer.',
        leftText: 'Not done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        dateText: 'Jun 4 - Jun 17',
        pointsLogic: 'Earn 500 pts when your proposed change is accepted.',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Counted progress',
      args: _detailArgs(
        title: 'Give kudos',
        description:
            'Recognize useful contributions from other members during the season.',
        leftText: '2 / 5 Kudos',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        dateText: 'Ends in 4d',
        pointsLogic: 'Earn points for each accepted kudos action, up to 5.',
        ctaLabel: 'Give kudos',
      ),
    ),
    _Scenario(
      name: 'Pending finalization',
      args: _detailArgs(
        title: 'Fill in survey',
        description: 'Share feedback that helps shape the next testnet season.',
        leftText: 'Submitted',
        rightText: 'pending 500 pts',
        progressHelperText: 'You submitted the feedback form.',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        dateText: 'Ends today',
        pointsLogic: 'Points are awarded after your response is reviewed.',
        ctaLabel: 'View survey',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Completed',
      args: _detailArgs(
        title: 'Fill in survey',
        description: 'You completed the survey for this season.',
        leftText: 'Done',
        rightText: 'completed 500 pts',
        progressHelperText: 'You submitted the feedback form.',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        dateText: 'Completed today',
        pointsLogic: 'You earned 500 pts for completing the survey.',
        ctaLabel: 'View activity',
        railTreatment: AtomicChallengeRailTreatment.checkbox,
      ),
    ),
    _Scenario(
      name: 'Background block production',
      args: _detailArgs(
        title: 'Produce Every Block - June 2026',
        description:
            'Keep your node online and ready during the season window.',
        leftText: '90% success',
        rightText: 'Earned 10,550 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        dateText: 'Season ends in 128d',
        pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
        ctaLabel: 'Check node',
        rules: 'Keep your node connected when you win a slot.',
        heroCard: _blockProductionHeroCard,
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
      ),
    ),
  ],
);

final $BackgroundBlockProduction = _Story(
  name: 'Background block production',
  args: _detailArgs(
    title: 'Produce Every Block - June 2026',
    description: 'Keep your node online and ready during the season window.',
    leftText: '90% success',
    rightText: 'Earned 10,550 pts',
    phase: AtomicChallengePhase.inProgress,
    fill: null,
    dateText: 'Season ends in 128d',
    pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
    ctaLabel: 'Check node',
    rules: 'Keep your node connected when you win a slot.',
    heroCard: _blockProductionHeroCard,
    railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
  ),
  scenarios: [
    _Scenario(
      name: 'Ongoing status',
      args: _detailArgs(
        title: 'Produce Every Block - June 2026',
        description:
            'Keep your node online and ready during the season window.',
        leftText: '90% success',
        rightText: 'Earned 10,550 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        dateText: 'Season ends in 128d',
        pointsLogic: 'Score = success rate x 5,000 assigned-slot points.',
        ctaLabel: 'Check node',
        rules: 'Keep your node connected when you win a slot.',
        heroCard: _blockProductionHeroCard,
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
      ),
    ),
  ],
);
