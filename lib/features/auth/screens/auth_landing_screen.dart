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
                  // Login and sign-up are one flow; the email step decides which.
                  label: l.authLogInOrSignUp,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () {
                    ref.read(authFlowProvider.notifier).start();
                    context.go(AppRoutes.authEmail);
                  },
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
              SizedBox(height: spacing.space8),
              TextButton(
                onPressed: () {
                  ref.read(authFlowProvider.notifier).start(recovery: true);
                  context.go(AppRoutes.authEmail);
                },
                child: Text(l.authForgotPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
