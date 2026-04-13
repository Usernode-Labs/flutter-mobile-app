import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/dapp_avatar.dart';

part 'dapp_avatar.stories.g.dart';

const meta = Meta<DappAvatar>(path: 'widgets/dapps');

final $Default = _Story(
  args: _Args(seed: StringArg('Mina Explorer'), size: Arg.fixed(48.0)),
  scenarios: [
    _Scenario(
      name: 'Multi-Word Name',
      args: _Args(seed: StringArg('Mina Explorer')),
    ),
    _Scenario(
      name: 'Single-Word Name',
      args: _Args(seed: StringArg('ZkApp')),
    ),
  ],
);

final $SingleWord = _Story(
  name: 'Single Word',
  args: _Args(seed: StringArg('ZkApp'), size: Arg.fixed(48.0)),
);

final $Large = _Story(
  name: 'Large',
  args: _Args(
    seed: StringArg('Block Producer Dashboard'),
    size: Arg.fixed(80.0),
  ),
);
