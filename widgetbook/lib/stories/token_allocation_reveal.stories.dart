import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'token_allocation_reveal.stories.g.dart';

const meta = Meta<TokenAllocationReveal>(path: 'live app/widgets/challenges');

final $Default = _Story(
  args: _Args(
    amount: StringArg('1,250'),
    label: StringArg('Indicative token allocation'),
    disclaimer: StringArg(
      'Your allocation is indicative and based on your Season 1 contributions. '
      'It is not a promise or entitlement. Any future distribution is '
      'conditional on mainnet launch, eligibility verification, acceptance of '
      'the applicable Usernode Testnet Program Terms, and remains subject to '
      'the company’s discretion.',
    ),
    revealLabel: StringArg('Reveal'),
    revealed: BoolArg(false),
  ),
  scenarios: [
    _Scenario(
      name: 'Hidden',
      args: _Args.fixed(amount: '1,250', revealed: false),
    ),
    _Scenario(
      name: 'Revealed',
      args: _Args.fixed(amount: '1,250', revealed: true),
    ),
    _Scenario(
      name: 'Large amount',
      args: _Args.fixed(amount: '128,400.5', revealed: true),
    ),
  ],
);

final $Revealed = _Story(
  name: 'Revealed',
  args: _Args(amount: StringArg('1,250'), revealed: BoolArg(true)),
);
