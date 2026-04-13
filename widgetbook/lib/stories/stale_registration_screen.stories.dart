import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/full_page_error_state.dart';

part 'stale_registration_screen.stories.g.dart';

/// Wrapper to give StaleRegistration stories a distinct component identity
/// from the generic FullPageErrorState stories.
class StaleRegistrationDemo extends StatelessWidget {
  const StaleRegistrationDemo({
    super.key,
    required this.message,
    this.detail,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return FullPageErrorState(
      message: message,
      detail: detail,
      onRetry: onRetry,
      retryLabel: retryLabel,
    );
  }
}

const meta = Meta<StaleRegistrationDemo>(path: 'pages/onboarding');

final $Default = _Story(
  args: _Args(
    message: StringArg('Registration expired'),
    detail: Arg.fixed(
      'Your registration has become stale. Please join our Discord for help.',
    ),
    onRetry: Arg.fixed(() {}),
    retryLabel: StringArg('Join Discord'),
  ),
  scenarios: [
    _Scenario(
      name: 'With Retry',
      args: _Args(
        message: StringArg('Registration expired'),
        onRetry: Arg.fixed(() {}),
        retryLabel: StringArg('Join Discord'),
      ),
    ),
    _Scenario(
      name: 'Without Retry',
      args: _Args(
        message: StringArg('Something went wrong'),
        onRetry: Arg.fixed(null),
      ),
    ),
  ],
);

final $NoRetry = _Story(
  name: 'No Retry',
  args: _Args(
    message: StringArg('Something went wrong'),
    detail: Arg.fixed('An unexpected error occurred. Please try again later.'),
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
