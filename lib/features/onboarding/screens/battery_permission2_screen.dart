import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class BatteryPermission2Screen extends ConsumerStatefulWidget {
  const BatteryPermission2Screen({super.key});

  @override
  ConsumerState<BatteryPermission2Screen> createState() =>
      _BatteryPermission2ScreenState();
}

class _BatteryPermission2ScreenState
    extends ConsumerState<BatteryPermission2Screen>
    with WidgetsBindingObserver {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialBatteryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed || !Platform.isAndroid) {
      return;
    }

    // When returning from Settings, automatically advance if battery
    // optimization has been disabled (unrestricted).
    await PlatformAlarmService.instance.initialize();
    final disabled =
        await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
    if (!mounted) return;
    if (disabled && context.mounted) {
      context.go(AppRoutes.onboardingBatteryComplete);
    }
  }

  Future<void> _checkInitialBatteryStatus() async {
    if (!Platform.isAndroid) return;

    await PlatformAlarmService.instance.initialize();
    final disabled =
        await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
    if (!mounted) return;

    // If battery optimizations are already disabled when this screen is first
    // shown, skip the remaining battery onboarding and go straight to the
    // produced blocks screen after marking onboarding complete.
    if (disabled) {
      await markOnboardingComplete();
      ref.invalidate(hasCompletedOnboardingProvider);
      if (!mounted) return;
      context.go(AppRoutes.mainNode);
    }
  }

  Future<void> _openSettings() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      if (Platform.isAndroid) {
        await PlatformAlarmService.instance.openBatteryOptimizationSettings();
      }
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  void _goToCompletionScreen() {
    if (!context.mounted) return;
    context.go(AppRoutes.onboardingBatteryComplete);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.permBatteryTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: spacing.space16),
                      Text(
                        isAndroid
                            ? l10n.permBatteryAndroidExplanation
                            : l10n.permBatteryIosExplanation,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (isAndroid) ...[
                        SizedBox(height: spacing.space24),
                        _StepRow(
                          number: 1,
                          text: l10n.onboardingBatteryStepAppUsage,
                        ),
                        SizedBox(height: spacing.space8),
                        _StepRow(
                          number: 2,
                          text: l10n.onboardingBatteryStepAllowBackground,
                        ),
                        SizedBox(height: spacing.space8),
                        _StepRow(
                          number: 3,
                          text: l10n.onboardingBatteryStepTapText,
                        ),
                        SizedBox(height: spacing.space8),
                        _StepRow(
                          number: 4,
                          text: l10n.onboardingBatteryStepSelectUnrestricted,
                        ),
                        SizedBox(height: spacing.space8),
                        _StepRow(
                          number: 5,
                          text: l10n.onboardingBatteryStepReturnToApp,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.space24),
              if (isAndroid) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _requesting ? null : _openSettings,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _requesting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.permOpenBatterySettings),
                  ),
                ),
                SizedBox(height: spacing.space8),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goToCompletionScreen,
                  style: isAndroid
                      ? FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurface,
                        )
                      : FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                  child: Text(
                    isAndroid ? l10n.permNotificationsSkip : l10n.commonFinish,
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

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: spacing.space8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
