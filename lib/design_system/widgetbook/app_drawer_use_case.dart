import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// AppDrawer use case — rendered as a visual preview since the actual widget
/// requires Riverpod providers, SharedPreferences, and localization.
WidgetbookComponent appDrawerComponent() {
  return WidgetbookComponent(
    name: 'AppDrawer',
    useCases: [
      WidgetbookUseCase(
        name: 'Preview',
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          // Visual preview of the drawer layout
          return SizedBox(
            width: 304,
            child: Material(
              color: colorScheme.surface,
              child: SafeArea(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          'Usernode',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'About',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Build Info'),
                      trailing: const Icon(Icons.info_outline),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
