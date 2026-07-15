import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Legal section — the standing entry point to the terms.
///
/// Always visible, not just to users who refused: someone who accepted has the
/// same right to re-read the terms and withdraw consent.
class LegalSettingsSection extends StatelessWidget {
  const LegalSettingsSection({super.key, required this.onTermsTap});

  final VoidCallback onTermsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListSectionHeader(title: l10n.settingsLegal),
        Card(
          child: ListTile(
            leading: const Icon(Symbols.gavel_sharp),
            title: Text(l10n.termsTitle),
            subtitle: Text(l10n.settingsTermsSubtitle),
            trailing: Icon(
              Symbols.chevron_right_sharp,
              size: sizing.iconSmall,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radii.large)),
            ),
            onTap: onTermsTap,
          ),
        ),
      ],
    );
  }
}
