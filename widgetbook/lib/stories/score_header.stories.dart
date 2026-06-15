import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/score_header.dart';

part 'score_header.stories.g.dart';

const meta = Meta<ScoreHeader>(path: 'live app/widgets/data-display');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    score: StringArg('8,000'),
    scoreLabel: StringArg('points'),
    rankLabel: StringArg('Rank 44'),
    progress: DoubleArg(0.65),
    countdownLabel: StringArg('ENDS IN'),
    countdownTime: StringArg('12 DAYS 5H 3M'),
    ctaLabel: StringArg('View in Leaderboard'),
    onCtaTap: Arg.fixed(() {}),
    variant: EnumArg(
      ScoreHeaderVariant.standard,
      values: ScoreHeaderVariant.values,
    ),
    glowIntensity: DoubleArg(1.0),
    countdownOpacity: DoubleArg(1.0),
    countdownTextMode: EnumArg(
      CountdownTextMode.normal,
      values: CountdownTextMode.values,
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'Standard',
      args: _Args(
        variant: EnumArg(
          ScoreHeaderVariant.standard,
          values: ScoreHeaderVariant.values,
        ),
      ),
    ),
    _Scenario(
      name: 'Glow',
      args: _Args(
        variant: EnumArg(
          ScoreHeaderVariant.glow,
          values: ScoreHeaderVariant.values,
        ),
        glowIntensity: DoubleArg(1.0),
      ),
    ),
    _Scenario(
      name: 'Glow Dim',
      args: _Args(
        variant: EnumArg(
          ScoreHeaderVariant.glow,
          values: ScoreHeaderVariant.values,
        ),
        glowIntensity: DoubleArg(0.3),
      ),
    ),
    _Scenario(
      name: 'Catching Up',
      args: _Args(
        countdownTextMode: EnumArg(
          CountdownTextMode.catchingUp,
          values: CountdownTextMode.values,
        ),
      ),
    ),
    _Scenario(
      name: 'Caught Up',
      args: _Args(
        countdownTextMode: EnumArg(
          CountdownTextMode.caughtUp,
          values: CountdownTextMode.values,
        ),
      ),
    ),
  ],
);

final $Glow = _Story(
  name: 'Glow',
  args: _Args(
    score: StringArg('12,450'),
    scoreLabel: StringArg('points'),
    rankLabel: StringArg('Rank 3'),
    progress: DoubleArg(0.92),
    countdownLabel: StringArg('ENDS IN'),
    countdownTime: StringArg('2 DAYS 14H 22M'),
    ctaLabel: StringArg('View in Leaderboard'),
    onCtaTap: Arg.fixed(() {}),
    variant: EnumArg(
      ScoreHeaderVariant.glow,
      values: ScoreHeaderVariant.values,
    ),
    glowIntensity: DoubleArg(1.0),
    countdownOpacity: DoubleArg(1.0),
    countdownTextMode: EnumArg(
      CountdownTextMode.normal,
      values: CountdownTextMode.values,
    ),
  ),
);

final $CaughtUp = _Story(
  name: 'Caught Up',
  args: _Args(
    score: StringArg('8,000'),
    scoreLabel: StringArg('points'),
    rankLabel: StringArg('Rank 44'),
    progress: DoubleArg(0.65),
    countdownOpacity: DoubleArg(1.0),
    countdownTextMode: EnumArg(
      CountdownTextMode.caughtUp,
      values: CountdownTextMode.values,
    ),
    variant: EnumArg(
      ScoreHeaderVariant.standard,
      values: ScoreHeaderVariant.values,
    ),
    glowIntensity: DoubleArg(1.0),
  ),
);
