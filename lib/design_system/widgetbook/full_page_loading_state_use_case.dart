import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/full_page_loading_state.dart';

WidgetbookComponent fullPageLoadingStateComponent() {
  return WidgetbookComponent(
    name: 'FullPageLoadingState',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          return const Scaffold(
            body: FullPageLoadingState(),
          );
        },
      ),
    ],
  );
}
