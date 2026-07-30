import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/onboarding/data/onboarding_providers.dart';

final _log = LoggingService.instance.withTag('usernode/WelcomeSetupScreen');

class WelcomeSetupScreen extends ConsumerStatefulWidget {
  const WelcomeSetupScreen({super.key});

  @override
  ConsumerState<WelcomeSetupScreen> createState() => _WelcomeSetupScreenState();
}

class _WelcomeSetupScreenState extends ConsumerState<WelcomeSetupScreen> {
  bool _provisioning = false;

  Future<void> _startSetup() async {
    if (_provisioning) return;
    setState(() => _provisioning = true);

    // Provision the local node account before the permission sequence. The
    // retired registration flow imported a server-issued key here; without
    // an account the router bounces every private route back to onboarding
    // (hasAny == false), so onboarding must not proceed until this succeeds.
    try {
      await ensureLocalNodeAccount(ref);
    } catch (e, st) {
      _log.error('Node account provisioning failed', error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'onboarding_provision_account');
      if (!mounted) return;
      setState(() => _provisioning = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingAccountSetupError)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _provisioning = false);
    context.go(
      Platform.isIOS
          ? AppRoutes.onboardingNotificationPermission3
          : AppRoutes.onboardingExactAlarmPermission1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userId = ref.watch(onboardingUserIdProvider) ?? '';
    final displayUserId = userId.isNotEmpty ? userId : 'user';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingWelcomeSetupTitle(displayUserId),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    SizedBox(height: spacing.space24),
                    Text(
                      l10n.onboardingWelcomeSetupBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l10n.onboardingWelcomeSetupStartButton,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  isLoading: _provisioning,
                  onTap: _startSetup,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
