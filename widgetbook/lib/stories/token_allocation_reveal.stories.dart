import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

part 'token_allocation_reveal.stories.g.dart';

const meta = Meta<TokenAllocationReveal>(path: 'live app/widgets/challenges');

final $Default = _Story(
  args: _Args(
    amount: StringArg('1,250'),
    label: StringArg('Token Allocation'),
    disclaimer: StringArg(
      'Token allocations contingent on mainnet, acceptance of the terms and '
      'conditions, and subject to the discretion of the company.',
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
