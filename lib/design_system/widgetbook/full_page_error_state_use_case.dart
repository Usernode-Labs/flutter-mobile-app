import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/full_page_error_state.dart';

WidgetbookComponent fullPageErrorStateComponent() {
  return WidgetbookComponent(
    name: 'FullPageErrorState',
    useCases: [
      _playground(),
      _variants(),
    ],
  );
}

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final message = context.knobs.string(
        label: 'Message',
        initialValue: 'Failed to load data',
      );
      final detail = context.knobs.stringOrNull(
        label: 'Detail',
        initialValue: 'Check your connection and try again',
      );
      final showRetry = context.knobs.boolean(
        label: 'Show Retry',
        initialValue: true,
      );
      final retryLabel = context.knobs.string(
        label: 'Retry Label',
        initialValue: 'Retry',
      );

      return FullPageErrorState(
        message: message,
        detail: detail,
        onRetry: showRetry ? () {} : null,
        retryLabel: retryLabel,
      );
    },
  );
}

WidgetbookUseCase _variants() {
  return WidgetbookUseCase(
    name: 'Common Variants',
    builder: (context) {
      return const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 250,
              child: FullPageErrorState(
                message: 'Failed to load data',
                detail: 'Check your connection and try again',
              ),
            ),
            SizedBox(
              height: 250,
              child: FullPageErrorState(
                message: 'Something went wrong',
              ),
            ),
          ],
        ),
      );
    },
  );
}
