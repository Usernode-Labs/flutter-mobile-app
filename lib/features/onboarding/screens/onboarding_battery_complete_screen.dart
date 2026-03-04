import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

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

  Future<void> _completeAndGoToProducedBlocks() async {
    await markOnboardingComplete();
    ref.invalidate(hasCompletedOnboardingProvider);
    if (!mounted) return;
    context.go(AppRoutes.nodeStatusProducedBlocks);
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
    await _completeAndGoToProducedBlocks();
  }

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
                  child: _checking
                      // ignore: deprecated_member_use_from_same_package
                      ? const FullPageLoadingState()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_unrestricted) ...[
                              Text(
                                l10n.onboardingBatteryUnrestrictedTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              SizedBox(height: spacing.space16),
                              Text(
                                l10n.onboardingBatteryUnrestrictedBody,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ] else ...[
                              Text(
                                l10n.onboardingBatteryDefaultTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              SizedBox(height: spacing.space16),
                              Text(
                                l10n.onboardingBatteryDefaultBody,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              SizedBox(height: spacing.space24),
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
