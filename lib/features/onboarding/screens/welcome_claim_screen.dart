import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class WelcomeClaimScreen extends StatelessWidget {
  const WelcomeClaimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.welcomeAlphaTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: spacing.space24),
                      Text(
                        l10n.welcomeAlphaSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l10n.welcomeAlphaClaimSpot,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () => context.go(AppRoutes.authLanding),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
