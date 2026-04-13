import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

// ignore: deprecated_member_use
import 'package:crypto_mobile_app/design_system/src/full_page_loading_state.dart';

part 'full_page_loading_state.stories.g.dart';

// ignore: deprecated_member_use
const meta = Meta<FullPageLoadingState>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(),
  scenarios: [
    _Scenario(name: 'Default', args: _Args.fixed()),
  ],
);
