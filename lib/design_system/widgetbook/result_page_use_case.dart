import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/result_page.dart';

WidgetbookComponent resultPageComponent() {
  return WidgetbookComponent(
    name: 'ResultPage',
    useCases: [
      _success(),
      _failure(),
      _info(),
    ],
  );
}

WidgetbookUseCase _success() {
  return WidgetbookUseCase(
    name: 'Success',
    builder: (context) {
      return ResultPage(
        variant: ResultPageVariant.success,
        title: 'Transaction Sent',
        subtitle: 'Your transaction has been submitted to the network.',
        primaryAction: FilledButton(
          onPressed: () {},
          child: const Text('Done'),
        ),
        secondaryAction: OutlinedButton(
          onPressed: () {},
          child: const Text('View Details'),
        ),
      );
    },
  );
}

WidgetbookUseCase _failure() {
  return WidgetbookUseCase(
    name: 'Failure',
    builder: (context) {
      return ResultPage(
        variant: ResultPageVariant.failure,
        title: 'Transaction Failed',
        subtitle: 'Insufficient balance. Please check your wallet.',
        primaryAction: FilledButton(
          onPressed: () {},
          child: const Text('Try Again'),
        ),
      );
    },
  );
}

WidgetbookUseCase _info() {
  return WidgetbookUseCase(
    name: 'Info',
    builder: (context) {
      return ResultPage(
        variant: ResultPageVariant.info,
        title: 'Setup Complete',
        subtitle: 'Your node is now configured and ready to operate.',
        primaryAction: FilledButton(
          onPressed: () {},
          child: const Text('Continue'),
        ),
      );
    },
  );
}
