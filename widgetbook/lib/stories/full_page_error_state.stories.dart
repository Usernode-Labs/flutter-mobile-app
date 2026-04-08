import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/full_page_error_state.dart';

part 'full_page_error_state.stories.g.dart';

const meta = Meta<FullPageErrorState>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(
    message: StringArg('Failed to load data'),
    detail: Arg.fixed('Please check your connection and try again.'),
    onRetry: Arg.fixed(() {}),
    retryLabel: StringArg('Retry'),
  ),
);

final $NoRetry = _Story(
  name: 'No Retry',
  args: _Args(
    message: StringArg('Something went wrong'),
    detail: Arg.fixed('An unexpected error occurred.'),
  ),
);

final $MinimalError = _Story(
  name: 'Minimal',
  args: _Args(message: StringArg('Error')),
);
