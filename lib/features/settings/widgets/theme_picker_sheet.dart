import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
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

    final l10n = AppLocalizations.of(context);
    return SheetLayout(
      title: l10n.settingsAppearance,
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
              title: Text(l10n.themeSystem, style: theme.textTheme.bodyLarge),
              subtitle: Text(
                l10n.themeSystemSubtitle,
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
              title: Text(l10n.themeLight, style: theme.textTheme.bodyLarge),
              shape: RoundedRectangleBorder(
                borderRadius: radii.borderRadiusSmall,
              ),
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              title: Text(l10n.themeDark, style: theme.textTheme.bodyLarge),
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
