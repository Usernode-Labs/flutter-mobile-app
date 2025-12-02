import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/onboarding/data/onboarding_providers.dart';

class WelcomeSetupScreen extends ConsumerWidget {
  const WelcomeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final userId = ref.watch(onboardingUserIdProvider) ?? '';
    final displayUserId =
        userId.isNotEmpty ? userId : 'user';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $displayUserId',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'You are part of the initial test cohort. This app runs a block producing node.\n\nWe need to configure your device to produce blocks on demand.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    context.go(
                      Platform.isIOS
                          ? AppRoutes.onboardingNotificationPermission3
                          : AppRoutes.onboardingExactAlarmPermission1,
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Start Setup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


