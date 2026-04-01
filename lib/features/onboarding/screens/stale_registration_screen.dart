import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class StaleRegistrationScreen extends StatelessWidget {
  const StaleRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: FullPageErrorState(
        message: l10n.registrationStaleTitle,
        detail: l10n.registrationStaleBody,
        onRetry: () => launchExternalUrl(AppConfig.discordInviteUrl),
        retryLabel: l10n.registrationStaleAction,
      ),
    );
  }
}
