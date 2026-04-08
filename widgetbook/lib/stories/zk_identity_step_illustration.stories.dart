import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_step_illustration.dart';

part 'zk_identity_step_illustration.stories.g.dart';

const meta = Meta<ZkIdentityStepIllustration>(path: 'widgets/challenges');

final $CheckApp = _Story(
  name: 'Check App (Step 0)',
  args: _Args(stepIndex: Arg.fixed(0)),
);

final $ConfirmScanned = _Story(
  name: 'Confirm Scanned (Step 1)',
  args: _Args(stepIndex: Arg.fixed(1)),
);

final $ReadyToVerify = _Story(
  name: 'Ready to Verify (Step 2)',
  args: _Args(stepIndex: Arg.fixed(2)),
);

final $Verification = _Story(
  name: 'Verification (Step 3)',
  args: _Args(stepIndex: Arg.fixed(3)),
);

final $Result = _Story(
  name: 'Result (Step 4)',
  args: _Args(stepIndex: Arg.fixed(4)),
);
