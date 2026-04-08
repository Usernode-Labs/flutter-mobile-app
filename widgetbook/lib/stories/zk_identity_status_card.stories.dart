import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/zk_identity_status_card.dart';

part 'zk_identity_status_card.stories.g.dart';

const meta = Meta<ZkIdentityStatusCard>(path: 'widgets/challenges');

final $Default = _Story(
  args: _Args(
    data: Arg.fixed(
      const ZkIdentityStatusData(
        steps: [
          ZkIdentityStatusStep(
            label: 'Proof ID',
            icon: Symbols.fingerprint_sharp,
            value: '0x7a3f…e91b',
            monospace: true,
          ),
          ZkIdentityStatusStep(
            label: 'Status',
            icon: Symbols.verified_sharp,
            value: 'Verified',
          ),
          ZkIdentityStatusStep(
            label: 'Created',
            icon: Symbols.schedule_sharp,
            value: '2 hours ago',
          ),
          ZkIdentityStatusStep(
            label: 'Expires',
            icon: Symbols.timer_sharp,
            value: 'in 22 hours',
          ),
        ],
      ),
    ),
  ),
);
