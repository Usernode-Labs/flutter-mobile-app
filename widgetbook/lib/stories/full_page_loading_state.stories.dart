import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

// ignore: deprecated_member_use
import 'package:crypto_mobile_app/design_system/src/full_page_loading_state.dart';

part 'full_page_loading_state.stories.g.dart';

const meta =
    MetaWithArgs<FullPageLoadingStateReview, FullPageLoadingStateStoryModel>(
      name: 'FullPageLoadingState',
      path: 'widgets/indicators',
    );

final defaults = _Defaults(builder: _buildFullPageLoadingState);

class FullPageLoadingStateStoryModel {
  const FullPageLoadingStateStoryModel();
}

class FullPageLoadingStateReview extends StatelessWidget {
  const FullPageLoadingStateReview({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return const FullPageLoadingState();
  }
}

FullPageLoadingStateReview _buildFullPageLoadingState(
  BuildContext context,
  FullPageLoadingStateStoryModelArgs args,
) {
  return const FullPageLoadingStateReview();
}

final $Default = _Story(
  args: _Args(),
  scenarios: [_Scenario(name: 'Default', args: _Args.fixed())],
);
