import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dapp_card.dart';

part 'dapp_card.stories.g.dart';

const meta = Meta<DappCard>(path: 'widgets/dapps');

final $Default = _Story(
  args: _Args(
    name: StringArg('Mina Explorer'),
    author: StringArg('Staketab'),
    description: StringArg(
      'A block explorer for the Mina blockchain with real-time data.',
    ),
    users: Arg.fixed(1250),
    txns: Arg.fixed(48000),
    onTap: Arg.fixed(() {}),
    enabled: BoolArg(true),
    disabledLabel: Arg.fixed(null),
  ),
);

final $Disabled = _Story(
  name: 'Disabled',
  args: _Args(
    name: StringArg('Coming Soon dApp'),
    author: StringArg('Community'),
    description: StringArg(DappCard.kDefaultDescription),
    users: Arg.fixed(null),
    txns: Arg.fixed(null),
    onTap: Arg.fixed(null),
    enabled: BoolArg(false),
    disabledLabel: StringArg('Coming Soon'),
  ),
);

final $NoStats = _Story(
  name: 'No Stats',
  args: _Args(
    name: StringArg('New dApp'),
    author: StringArg('Developer'),
    description: StringArg('A brand new decentralized application.'),
    users: Arg.fixed(null),
    txns: Arg.fixed(null),
    onTap: Arg.fixed(() {}),
    enabled: BoolArg(true),
    disabledLabel: Arg.fixed(null),
  ),
);
