import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class StaleRegistrationScreen extends StatelessWidget {
  const StaleRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final info = snapshot.data!;
                  return Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      'v${info.version} (${info.buildNumber})',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              Icon(
                Icons.warning_amber_rounded,
                size: 64,
                color: theme.colorScheme.error,
              ),
              SizedBox(height: spacing.space24),
              Text(
                l10n.registrationStaleTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.space16),
              Text(
                l10n.registrationStaleBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              Button(
                label: l10n.registrationStaleAction,
                variant: ButtonVariant.primary,
                size: ButtonSize.large,
                onTap: () => context.go(AppRoutes.onboardingImportApi),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
