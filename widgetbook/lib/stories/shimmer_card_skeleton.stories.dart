import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/shimmer_block.dart';
import 'package:crypto_mobile_app/design_system/src/shimmer_card_skeleton.dart';

part 'shimmer_card_skeleton.stories.g.dart';

const meta = Meta<ShimmerCardSkeleton>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(),
  setup: (context, child, args) {
    return ShimmerHost(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 360, child: child),
      ),
    );
  },
  scenarios: [_Scenario(name: 'Challenge card loading')],
);
