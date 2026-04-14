import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class DiagnosticsSettingsSection extends StatelessWidget {
  const DiagnosticsSettingsSection({
    super.key,
    required this.onDeviceBenchmarkTap,
  });

  final VoidCallback onDeviceBenchmarkTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final l10n = AppLocalizations.of(context);

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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(radii.large),
              ),
            ),
            onTap: onDeviceBenchmarkTap,
          ),
        ),
      ],
    );
  }
}
