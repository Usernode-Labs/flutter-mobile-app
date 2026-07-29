import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class WelcomeClaimScreen extends ConsumerWidget {
  const WelcomeClaimScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // A signed-in user proceeds straight to node-account setup; everyone
    // else goes through auth first. Without this branch, authenticated
    // users loop: CTA -> /auth -> authRedirect bounces them to splash ->
    // no local account -> back to this screen.
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

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
                  onTap: () => context.go(isAuthenticated
                      ? AppRoutes.onboardingWelcomeSetup
                      : AppRoutes.authLanding),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
