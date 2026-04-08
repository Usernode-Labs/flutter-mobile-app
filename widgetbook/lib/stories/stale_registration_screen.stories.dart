import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/full_page_error_state.dart';

part 'stale_registration_screen.stories.g.dart';

const meta = Meta<FullPageErrorState>(path: 'widgets/indicators');

final $Default = _Story(
  args: _Args(
    message: StringArg('Registration expired'),
    detail: StringArg(
      'Your registration has become stale. Please join our Discord for help.',
    ),
    onRetry: Arg.fixed(() {}),
    retryLabel: StringArg('Join Discord'),
  ),
);

final $NoRetry = _Story(
  name: 'No Retry',
  args: _Args(
    message: StringArg('Something went wrong'),
    detail: StringArg('An unexpected error occurred. Please try again later.'),
    onRetry: Arg.fixed(null),
    retryLabel: StringArg('Retry'),
  ),
);

final $MinimalError = _Story(
  name: 'Minimal Error',
  args: _Args(
    message: StringArg('Failed to load data'),
    detail: Arg.fixed(null),
    onRetry: Arg.fixed(() {}),
    retryLabel: StringArg('Retry'),
  ),
);
