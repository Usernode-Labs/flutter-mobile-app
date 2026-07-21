import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

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
                        l.authLandingTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: spacing.space24),
                      Text(
                        l.authLandingSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l.authLogIn,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () => context.go(AppRoutes.authEmail),
                ),
              ),
              SizedBox(height: spacing.space12),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l.authSignIn,
                  size: ButtonSize.large,
                  onTap: () => context.go(AppRoutes.authEmail),
                ),
              ),
              SizedBox(height: spacing.space12),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l.authContinueGuest,
                  variant: ButtonVariant.outlined,
                  size: ButtonSize.large,
                  onTap: () async {
                    await ref
                        .read(authStatusProvider.notifier)
                        .continueAsGuest();
                    if (context.mounted) context.go(AppRoutes.splash);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
