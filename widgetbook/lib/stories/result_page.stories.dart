import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/src/result_page.dart';

part 'result_page.stories.g.dart';

const meta = Meta<ResultPage>(path: 'pages/outcomes');

final $Success = _Story(
  name: 'Success',
  args: _Args(
    variant: EnumArg(
      ResultPageVariant.success,
      values: ResultPageVariant.values,
    ),
    icon: Arg.fixed(null),
    title: StringArg('Transaction Sent'),
    subtitle: StringArg(
      'Your transaction has been submitted to the network and will be confirmed shortly.',
    ),
    primaryAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('Done')),
    ),
    secondaryAction: Arg.fixed(
      TextButton(onPressed: () {}, child: const Text('View Details')),
    ),
  ),
  scenarios: [
    _Scenario(
      name: 'Success',
      args: _Args(
        variant: EnumArg(
          ResultPageVariant.success,
          values: ResultPageVariant.values,
        ),
        title: StringArg('Transaction Sent'),
      ),
    ),
    _Scenario(
      name: 'Failure',
      args: _Args(
        variant: EnumArg(
          ResultPageVariant.failure,
          values: ResultPageVariant.values,
        ),
        title: StringArg('Transaction Failed'),
      ),
    ),
    _Scenario(
      name: 'Info',
      args: _Args(
        variant: EnumArg(
          ResultPageVariant.info,
          values: ResultPageVariant.values,
        ),
        title: StringArg('Delegation Updated'),
      ),
    ),
  ],
);

final $Failure = _Story(
  name: 'Failure',
  args: _Args(
    variant: EnumArg(
      ResultPageVariant.failure,
      values: ResultPageVariant.values,
    ),
    icon: Arg.fixed(null),
    title: StringArg('Transaction Failed'),
    subtitle: StringArg(
      'Insufficient balance to complete this transaction. Please check your funds.',
    ),
    primaryAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('Try Again')),
    ),
    secondaryAction: Arg.fixed(null),
  ),
);

final $Info = _Story(
  name: 'Info',
  args: _Args(
    variant: EnumArg(ResultPageVariant.info, values: ResultPageVariant.values),
    icon: Arg.fixed(null),
    title: StringArg('Delegation Updated'),
    subtitle: StringArg(
      'Your delegation change will take effect at the start of the next epoch.',
    ),
    primaryAction: Arg.fixed(
      FilledButton(onPressed: () {}, child: const Text('OK')),
    ),
    secondaryAction: Arg.fixed(null),
  ),
);

final $Minimal = _Story(
  name: 'Minimal',
  args: _Args(
    variant: EnumArg(
      ResultPageVariant.success,
      values: ResultPageVariant.values,
    ),
    icon: Arg.fixed(null),
    title: StringArg('Done'),
    subtitle: Arg.fixed(null),
    primaryAction: Arg.fixed(null),
    secondaryAction: Arg.fixed(null),
  ),
);
