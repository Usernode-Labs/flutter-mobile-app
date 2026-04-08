import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_category_icon.dart';

part 'challenge_category_icon.stories.g.dart';

const meta = Meta<ChallengeCategoryIcon>(path: 'widgets/challenges');

final $Default = _Story(
  name: 'Default',
  args: _Args(
    category: EnumArg(
      ChallengeCategory.technical,
      values: ChallengeCategory.values,
    ),
    muted: BoolArg(false),
    size: DoubleArg(48),
  ),
);

final $Muted = _Story(
  name: 'Muted',
  args: _Args(
    category: EnumArg(
      ChallengeCategory.flash,
      values: ChallengeCategory.values,
    ),
    muted: BoolArg(true),
    size: DoubleArg(48),
  ),
);
