import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/widgets/app_card.dart';
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
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.authLandingTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  SizedBox(height: spacing.space24),

                  // Members: login / sign-up (one flow).
                  //
                  // No "forgot password" link for now: the v4 backend
                  // deliberately refuses to issue a set-password token for
                  // accounts that already have a password (its OTP flow
                  // would otherwise double as an unauthenticated password
                  // reset for shared platform accounts), so the recovery
                  // flow cannot succeed against it. Re-add once the
                  // platform ships a real reset flow. The AuthFlowState
                  // `recovery` machinery is kept for that day.
                  _AuthCard(
                    title: l.authLoginCardTitle,
                    body: l.authLoginCardBody,
                    child: Button(
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

                  // Guests: browse without an account.
                  _AuthCard(
                    title: l.authGuestCardTitle,
                    body: l.authGuestCardBody,
                    child: Button(
                      label: l.authContinueGuest,
                      variant: ButtonVariant.outlined,
                      size: ButtonSize.large,
                      onTap: () async {
                        await ref
                            .read(identityProvider.notifier)
                            .continueAsGuest();
                        if (context.mounted) context.go(AppRoutes.splash);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled card with an explainer and an action below it.
class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    return AppCard(
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          SizedBox(height: spacing.space8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space16),
          child,
        ],
      ),
    );
  }
}
