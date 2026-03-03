import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Bottom sheet with 3 RadioListTiles for theme selection.
class ThemePickerSheet extends StatelessWidget {
  const ThemePickerSheet({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;

    return SheetLayout(
      title: 'Appearance',
      child: RadioGroup<ThemeMode>(
        groupValue: currentMode,
        onChanged: (mode) {
          if (mode != null) onChanged(mode);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              title: Text('System', style: theme.textTheme.bodyLarge),
              subtitle: Text(
                'Follow your device setting',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: radii.borderRadiusSmall,
              ),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              title: Text('Light', style: theme.textTheme.bodyLarge),
              shape: RoundedRectangleBorder(
                borderRadius: radii.borderRadiusSmall,
              ),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              title: Text('Dark', style: theme.textTheme.bodyLarge),
              shape: RoundedRectangleBorder(
                borderRadius: radii.borderRadiusSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
