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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l.authLandingTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              Button(
                label: l.authLogIn,
                variant: ButtonVariant.primary,
                onTap: () => context.go(AppRoutes.authEmail),
              ),
              const SizedBox(height: 12),
              Button(
                label: l.authSignIn,
                onTap: () => context.go(AppRoutes.authEmail),
              ),
              const SizedBox(height: 12),
              Button(
                label: l.authContinueGuest,
                variant: ButtonVariant.outlined,
                onTap: () async {
                  await ref.read(authStatusProvider.notifier).continueAsGuest();
                  if (context.mounted) context.go(AppRoutes.splash);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
