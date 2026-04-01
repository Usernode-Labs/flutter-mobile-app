import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/full_page_error_state.dart';

WidgetbookComponent staleRegistrationScreenComponent() {
  return WidgetbookComponent(
    name: 'StaleRegistrationScreen',
    useCases: [
      _preview(),
    ],
  );
}

WidgetbookUseCase _preview() {
  return WidgetbookUseCase(
    name: 'Preview',
    builder: (context) {
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'Registration Expired',
      );
      final body = context.knobs.string(
        label: 'Body',
        initialValue:
            "Your registration is from a previous season. Blocks produced "
            "with old credentials won't earn points. Please contact the "
            "team on Discord for assistance.",
      );
      final actionLabel = context.knobs.string(
        label: 'Action Label',
        initialValue: 'Contact us on Discord',
      );

      return Scaffold(
        body: FullPageErrorState(
          message: title,
          detail: body,
          onRetry: () {},
          retryLabel: actionLabel,
        ),
      );
    },
  );
}
