import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// NodeStatusIcon use case — visual preview of all status states.
/// The actual widget requires Riverpod nodeStatusProvider and Rust backend.
WidgetbookComponent nodeStatusIconComponent() {
  return WidgetbookComponent(
    name: 'NodeStatusIcon',
    useCases: [
      WidgetbookUseCase(
        name: 'All States',
        builder: (context) {
          final colorScheme = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusRow(
                  'Connecting',
                  Icons.hourglass_empty,
                  colorScheme.outline,
                  textTheme,
                ),
                const SizedBox(height: 24),
                _statusRow(
                  'Syncing',
                  Icons.sync,
                  colorScheme.primary,
                  textTheme,
                ),
                const SizedBox(height: 24),
                _statusRow(
                  'Synced',
                  Icons.check_circle,
                  colorScheme.tertiary,
                  textTheme,
                ),
                const SizedBox(height: 24),
                _statusRow(
                  'Error',
                  Icons.error,
                  colorScheme.error,
                  textTheme,
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

Widget _statusRow(
  String label,
  IconData icon,
  Color color,
  TextTheme textTheme,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 40,
        height: 40,
        child: Center(child: Icon(icon, color: color, size: 20)),
      ),
      const SizedBox(width: 12),
      Text(label, style: textTheme.bodyLarge),
    ],
  );
}
