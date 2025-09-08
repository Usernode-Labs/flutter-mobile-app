import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../constants/app_constants.dart';

Widget buildScaffold(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String screenName,
}) {
  final l10n = AppLocalizations.of(context);

  return Scaffold(
    appBar: Navigator.of(context).canPop()
        ? AppBar(
            leading: const BackButton(),
            elevation: 0,
            backgroundColor: Colors.transparent,
          )
        : null,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppConstants.placeholderIconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            screenName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.comingSoon, // 🔥 USING: l10n variable
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
