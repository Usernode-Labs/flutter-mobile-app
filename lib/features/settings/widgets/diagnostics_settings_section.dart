import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DiagnosticsSettingsSection extends StatelessWidget {
  const DiagnosticsSettingsSection({
    super.key,
    required this.onDeviceBenchmarkTap,
    required this.debugModeEnabled,
    required this.onDebugModeChanged,
    required this.onHttpLogsTap,
  });

  final VoidCallback onDeviceBenchmarkTap;

  /// Whether Debug Mode (in-memory HTTP capture) is on.
  final bool debugModeEnabled;
  final ValueChanged<bool> onDebugModeChanged;

  /// Opens the captured HTTP log viewer. Only reachable while
  /// [debugModeEnabled] is true.
  final VoidCallback onHttpLogsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final l10n = AppLocalizations.of(context);

    final tileShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(radii.large)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: l10n.settingsDiagnostics),
        Card(
          child: ListTile(
            leading: const Icon(Symbols.speed_sharp),
            title: Text(l10n.settingsDeviceBenchmark),
            subtitle: Text(l10n.settingsDeviceBenchmarkSubtitle),
            trailing: Icon(
              Symbols.chevron_right_sharp,
              size: sizing.iconSmall,
            ),
            shape: tileShape,
            onTap: onDeviceBenchmarkTap,
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Symbols.bug_report_sharp),
                title: Text(l10n.settingsDebugMode),
                subtitle: Text(
                  debugModeEnabled
                      ? l10n.settingsDebugModeEnabled
                      : l10n.settingsDebugModeDisabled,
                ),
                value: debugModeEnabled,
                onChanged: onDebugModeChanged,
              ),
              if (debugModeEnabled)
                ListTile(
                  leading: const Icon(Symbols.terminal_sharp),
                  title: Text(l10n.settingsHttpLogs),
                  subtitle: Text(l10n.settingsHttpLogsSubtitle),
                  trailing: Icon(
                    Symbols.chevron_right_sharp,
                    size: sizing.iconSmall,
                  ),
                  onTap: onHttpLogsTap,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
