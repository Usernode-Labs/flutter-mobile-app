import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Tier 2: General settings section — Appearance and Build Info.
class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({
    super.key,
    required this.currentThemeLabel,
    required this.buildInfoSubtitle,
    required this.onAppearanceTap,
    required this.onBuildInfoTap,
    required this.onBuildInfoLongPress,
  });

  /// Display label for the current theme mode (e.g. "System", "Light", "Dark").
  final String currentThemeLabel;

  /// Short build info string like "v1.2.3 · abc1234".
  final String buildInfoSubtitle;

  final VoidCallback onAppearanceTap;
  final VoidCallback onBuildInfoTap;
  final GestureLongPressCallback onBuildInfoLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radii = theme.extension<AppRadii>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: AppLocalizations.of(context).settingsGeneral),
        Card(
          child: ListTileTheme(
            minTileHeight: 48,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Symbols.palette_sharp),
                  title: Text(AppLocalizations.of(context).settingsAppearance),
                  trailing: TextChevronTrailing(text: currentThemeLabel),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(radii.large),
                      topRight: Radius.circular(radii.large),
                    ),
                  ),
                  onTap: onAppearanceTap,
                ),
                GestureDetector(
                  onLongPress: onBuildInfoLongPress,
                  child: ListTile(
                    leading: const Icon(Symbols.info_sharp),
                    title: Text(AppLocalizations.of(context).settingsBuildInfo),
                    subtitle: Text(
                      buildInfoSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: kMonoFontFamily,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Symbols.chevron_right_sharp,
                      size: theme.extension<AppSizing>()!.iconSmall,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(radii.large),
                        bottomRight: Radius.circular(radii.large),
                      ),
                    ),
                    onTap: onBuildInfoTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
