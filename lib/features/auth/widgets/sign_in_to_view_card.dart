import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

/// Shown on data screens when the user is browsing as a guest: the v3 data
/// endpoints require a session token, so there's nothing to show until they
/// sign in. Tapping the button routes to the auth landing.
class SignInToViewCard extends StatelessWidget {
  const SignInToViewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l.authSignInToView,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Button(
              label: l.authSignInToViewCta,
              variant: ButtonVariant.primary,
              onTap: () => context.go(AppRoutes.authLanding),
            ),
          ],
        ),
      ),
    );
  }
}
