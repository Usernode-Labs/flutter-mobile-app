import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/core/widgets/app_bar.dart';

WidgetbookComponent appBarComponent() {
  return WidgetbookComponent(
    name: 'AppAppBar',
    useCases: [
      WidgetbookUseCase(
        name: 'Default',
        builder: (context) {
          final showTitle = context.knobs.boolean(
            label: 'Show Title',
            initialValue: true,
          );
          final centerTitle = context.knobs.boolean(
            label: 'Center Title',
            initialValue: false,
          );

          return ProviderScope(
            child: Scaffold(
              appBar: AppAppBar(
                title: showTitle
                    ? context.knobs.string(
                        label: 'Title',
                        initialValue: 'Node Status',
                      )
                    : null,
                centerTitle: centerTitle,
                showNodeStatus: false,
                actions: context.knobs.boolean(
                  label: 'Show Actions',
                  initialValue: false,
                )
                    ? [
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {},
                        ),
                      ]
                    : null,
              ),
              body: const Center(child: Text('Page content')),
            ),
          );
        },
      ),
    ],
  );
}
