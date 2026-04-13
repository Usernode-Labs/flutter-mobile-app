import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/burst_pulse_illustration.dart';

part 'burst_pulse_illustration.stories.g.dart';

const meta = Meta<BurstPulseIllustration>(path: 'widgets/wallet');

final $Default = _Story(
  args: _Args(
    rings: Arg.fixed([
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.failed,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.failed,
      BurstRingOutcome.succeeded,
    ]),
    active: BoolArg(true),
  ),
  scenarios: [
    _Scenario(
      name: 'Mixed Outcomes',
      args: _Args(
        rings: Arg.fixed([
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.failed,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.failed,
          BurstRingOutcome.succeeded,
        ]),
        active: BoolArg(true),
      ),
    ),
    _Scenario(
      name: 'All Succeeded',
      args: _Args(
        rings: Arg.fixed([
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
          BurstRingOutcome.succeeded,
        ]),
        active: BoolArg(true),
      ),
    ),
  ],
);

final $AllSucceeded = _Story(
  name: 'All Succeeded',
  args: _Args(
    rings: Arg.fixed([
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
      BurstRingOutcome.succeeded,
    ]),
    active: BoolArg(true),
  ),
);

final $Inactive = _Story(
  name: 'Inactive',
  args: _Args(
    rings: Arg.fixed([
      BurstRingOutcome.succeeded,
      BurstRingOutcome.failed,
      BurstRingOutcome.succeeded,
    ]),
    active: BoolArg(false),
  ),
);
