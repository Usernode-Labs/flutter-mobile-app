import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

class OnboardingBatteryCompleteScreen extends ConsumerStatefulWidget {
  const OnboardingBatteryCompleteScreen({super.key});

  @override
  ConsumerState<OnboardingBatteryCompleteScreen> createState() =>
      _OnboardingBatteryCompleteScreenState();
}

class _OnboardingBatteryCompleteScreenState
    extends ConsumerState<OnboardingBatteryCompleteScreen> {
  bool _checking = true;
  bool _unrestricted = false;

  @override
  void initState() {
    super.initState();
    _checkBatteryStatus();
  }

  Future<void> _checkBatteryStatus() async {
    if (!Platform.isAndroid) {
      // Battery optimization concept is Android-specific; treat others as unrestricted.
      setState(() {
        _unrestricted = true;
        _checking = false;
      });
      return;
    }

    await PlatformAlarmService.instance.initialize();
    final disabled =
        await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
    if (!mounted) return;
    setState(() {
      _unrestricted = disabled;
      _checking = false;
    });
  }

  Future<void> _onContinue() async {
    await markOnboardingComplete();
    ref.invalidate(hasCompletedOnboardingProvider);
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: _checking
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_unrestricted) ...[
                                Text(
                                  'Unrestricted Battery Mode Active',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Great job! The app is now protected from being killed in the background.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ] else ...[
                                Text(
                                  'Tap Continue to start the main app',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'We strongly recommend you enable unrestricted battery optimizations to ensure consistent background block production.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _onContinue,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    'Continue',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


