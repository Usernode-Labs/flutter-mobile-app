import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/empty_state.dart';

WidgetbookComponent emptyStateComponent() {
  return WidgetbookComponent(
    name: 'EmptyState',
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
      final title = context.knobs.string(
        label: 'Title',
        initialValue: 'No transactions yet',
      );
      final subtitle = context.knobs.stringOrNull(
        label: 'Subtitle',
        initialValue: 'Your transactions will appear here',
      );
      final showAction = context.knobs.boolean(
        label: 'Show Action',
        initialValue: false,
      );

      return EmptyState(
        icon: Symbols.inbox_sharp,
        title: title,
        subtitle: subtitle,
        action: showAction
            ? FilledButton(
                onPressed: () {},
                child: const Text('Get Started'),
              )
            : null,
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
              height: 200,
              child: EmptyState(
                icon: Symbols.inbox_sharp,
                title: 'No transactions',
                subtitle: 'Send or receive to get started',
              ),
            ),
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Symbols.search_off_sharp,
                title: 'No results found',
                subtitle: 'Try adjusting your search',
              ),
            ),
            SizedBox(
              height: 200,
              child: EmptyState(
                icon: Symbols.wifi_off_sharp,
                title: 'No connection',
                subtitle: 'Check your internet connection',
              ),
            ),
          ],
        ),
      );
    },
  );
}
