import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// WonSlotItem use case — visual preview of all slot status states.
/// The actual widget requires RpcEpochWonSlot (Rust-generated type).
WidgetbookComponent wonSlotItemComponent() {
  return WidgetbookComponent(
    name: 'WonSlotItem',
    useCases: [
      WidgetbookUseCase(
        name: 'All States',
        builder: (context) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _slotPreview(
                  theme: theme,
                  colorScheme: colorScheme,
                  statusLabel: 'PRODUCED',
                  statusColor: Colors.green,
                  icon: Icons.check_circle,
                  slotNumber: 12345,
                  time: 'Today at 14:32:10',
                ),
                _slotPreview(
                  theme: theme,
                  colorScheme: colorScheme,
                  statusLabel: 'UPCOMING',
                  statusColor: colorScheme.primary,
                  icon: Icons.schedule,
                  slotNumber: 12390,
                  time: 'Today at 15:10:00',
                ),
                _slotPreview(
                  theme: theme,
                  colorScheme: colorScheme,
                  statusLabel: 'MISSED',
                  statusColor: Colors.red,
                  icon: Icons.cancel,
                  slotNumber: 12300,
                  time: 'Today at 13:45:20',
                ),
                _slotPreview(
                  theme: theme,
                  colorScheme: colorScheme,
                  statusLabel: 'ORPHANED',
                  statusColor: Colors.orange,
                  icon: Icons.warning_amber,
                  slotNumber: 12280,
                  time: 'Today at 12:30:00',
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

Widget _slotPreview({
  required ThemeData theme,
  required ColorScheme colorScheme,
  required String statusLabel,
  required Color statusColor,
  required IconData icon,
  required int slotNumber,
  required String time,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: statusColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: statusColor.withValues(alpha: 0.3),
        width: 1.5,
      ),
    ),
    child: Row(
      children: [
        Icon(icon, color: statusColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Slot #$slotNumber',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    ),
  );
}
