import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/text_chevron_trailing.dart';

part 'text_chevron_trailing.stories.g.dart';

const meta = Meta<TextChevronTrailing>(path: 'live app/widgets/data-display');

final $Default = _Story(
  args: _Args(text: StringArg('View All')),
  scenarios: [
    _Scenario(
      name: 'Default',
      args: _Args(text: StringArg('View All')),
    ),
  ],
);
