import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'atomic_challenge_card.stories.g.dart';

const meta = MetaWithArgs<AtomicChallengeCard, AtomicChallengeCardInput>(
  path: 'prototypes/challenges',
);

class AtomicChallengeCardInput {
  const AtomicChallengeCardInput({
    this.title = 'Give kudos',
    this.leftText = '2 / 5 Kudos',
    this.rightText = '400 / 1,500 pts',
    this.phase = AtomicChallengePhase.inProgress,
    this.fill = 0.4,
    this.cardWidth = 358,
    this.featured = false,
    this.railTreatment = AtomicChallengeRailTreatment.standard,
  });

  final String title;
  final String leftText;
  final String rightText;
  final AtomicChallengePhase phase;
  final double? fill;
  final double cardWidth;
  final bool featured;
  final AtomicChallengeRailTreatment railTreatment;
}

final defaults = _Defaults(
  builder: (context, args) {
    return AtomicChallengeCard(
      title: args.title,
      leftText: args.leftText,
      rightText: args.rightText,
      phase: args.phase,
      fill: args.fill,
      featured: args.featured,
      railTreatment: args.railTreatment,
      onTap: () {},
    );
  },
  setup: (context, child, args) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: args.cardWidth, child: child),
    );
  },
);

_Args _atomicArgs({
  required String title,
  required String leftText,
  required String rightText,
  required AtomicChallengePhase phase,
  required double? fill,
  double cardWidth = 358,
  bool featured = false,
  AtomicChallengeRailTreatment railTreatment =
      AtomicChallengeRailTreatment.standard,
  bool featuredTogglable = true,
}) {
  if (!featuredTogglable) {
    return _Args.fixed(
      title: title,
      leftText: leftText,
      rightText: rightText,
      phase: phase,
      fill: fill,
      cardWidth: cardWidth,
      featured: featured,
      railTreatment: railTreatment,
    );
  }

  return _Args(
    title: Arg.fixed(title),
    leftText: Arg.fixed(leftText),
    rightText: Arg.fixed(rightText),
    phase: Arg.fixed(phase),
    fill: Arg.fixed(fill),
    cardWidth: Arg.fixed(cardWidth),
    featured: BoolArg(featured),
    railTreatment: Arg.fixed(railTreatment),
  );
}

final $AtomicRail = _Story(
  name: 'Atomic rail',
  args: _Args(
    title: StringArg('Give kudos'),
    leftText: StringArg('2 / 5 Kudos'),
    rightText: StringArg('400 / 1,500 pts'),
    phase: EnumArg(
      AtomicChallengePhase.inProgress,
      values: AtomicChallengePhase.values,
    ),
    fill: NullableDoubleArg(
      0.4,
      style: const SliderDoubleArgStyle(min: 0, max: 1, divisions: 20),
    ),
    cardWidth: DoubleArg(
      358,
      style: const SliderDoubleArgStyle(min: 280, max: 430, divisions: 30),
    ),
    featured: BoolArg(false),
    railTreatment: EnumArg(
      AtomicChallengeRailTreatment.standard,
      values: AtomicChallengeRailTreatment.values,
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'One step open',
      args: _atomicArgs(
        title: 'Fill in survey',
        leftText: 'Not done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'One step pending',
      args: _atomicArgs(
        title: 'Fill in survey',
        leftText: 'Submitted',
        rightText: '500 pts',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'One step completed',
      args: _atomicArgs(
        title: 'Fill in survey',
        leftText: 'Done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted open',
      args: _atomicArgs(
        title: 'Give kudos',
        leftText: '0 / 5 Kudos',
        rightText: '0 / 1,500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted progress',
      args: _atomicArgs(
        title: 'Give kudos',
        leftText: '2 / 5 Kudos',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Counted pending',
      args: _atomicArgs(
        title: 'Give kudos',
        leftText: '5 / 5 Kudos',
        rightText: 'pending 1,500 pts',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: 1,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Submitted review',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: 'Submitted',
        rightText: 'waiting review',
        phase: AtomicChallengePhase.pendingFinalization,
        fill: null,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Continuous atomic',
      args: _atomicArgs(
        title: 'Produce blocks this month',
        leftText: '90% success',
        rightText: '4,500 / 6,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.9,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Background block production',
      args: _atomicArgs(
        title: 'Produce Every Block',
        leftText: '90% success',
        rightText: 'Earned 10,550.1 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: null,
        railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Economic eligible',
      args: _atomicArgs(
        title: 'Opinion Market',
        leftText: 'Eligible',
        rightText: '2,500 / 5,000 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.5,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured action',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: 'Not done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        featured: true,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured progress',
      args: _atomicArgs(
        title: 'Give kudos',
        leftText: '2 / 5 Kudos',
        rightText: '400 / 1,500 pts',
        phase: AtomicChallengePhase.inProgress,
        fill: 0.4,
        featured: true,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Featured completed',
      args: _atomicArgs(
        title: 'Propose an app change',
        leftText: 'Done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.completed,
        fill: 1,
        featured: true,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
    _Scenario(
      name: 'Narrow long title',
      args: _atomicArgs(
        title: 'Submit a dApp improvement proposal',
        leftText: 'Not done',
        rightText: '500 pts',
        phase: AtomicChallengePhase.open,
        fill: 0,
        cardWidth: 300,
        railTreatment: AtomicChallengeRailTreatment.checkbox,
        featuredTogglable: false,
      ),
    ),
  ],
);

final $BackgroundBlockProduction = _Story(
  name: 'Background block production',
  args: _atomicArgs(
    title: 'Produce Every Block',
    leftText: '90% success',
    rightText: 'Earned 10,550.1 pts',
    phase: AtomicChallengePhase.inProgress,
    fill: null,
    railTreatment: AtomicChallengeRailTreatment.technicalOngoing,
    featuredTogglable: false,
  ),
);
