import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class ExactAlarmPermission1Screen extends StatefulWidget {
  const ExactAlarmPermission1Screen({super.key});

  @override
  State<ExactAlarmPermission1Screen> createState() =>
      _ExactAlarmPermission1ScreenState();
}

class _ExactAlarmPermission1ScreenState
    extends State<ExactAlarmPermission1Screen> {
  bool _checking = true;
  bool _hasExactAlarm = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await PlatformAlarmService.instance.initialize();
    final has = await PlatformAlarmService.instance.hasExactAlarmPermission();
    if (!mounted) return;
    // If exact alarm permission is already granted (or we're not on Android),
    // skip this screen entirely and move straight to the next step.
    if (has || !Platform.isAndroid) {
      context.go(AppRoutes.onboardingNotificationPermission3);
      return;
    }
    setState(() {
      _hasExactAlarm = has;
      _checking = false;
    });
  }

  Future<void> _requestExactAlarm() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final l10n = AppLocalizations.of(context);
    try {
      final granted =
          await PlatformAlarmService.instance.requestExactAlarmOnly();
      if (!mounted) return;
      setState(() => _hasExactAlarm = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? l10n.permExactAlarmGranted
                : l10n.permExactAlarmEnableInSettings,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permExactAlarmsTitle)),
      body: _checking
          ? const FullPageLoadingState()
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(spacing.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.permExactAlarmsWhy,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: spacing.space8),
                    Text(
                      isAndroid
                          ? l10n.permExactAlarmsAndroidExplanation
                          : l10n.permExactAlarmsIosExplanation,
                    ),
                    SizedBox(height: spacing.space16),
                    if (isAndroid && !_hasExactAlarm)
                      FilledButton.tonal(
                        onPressed: _requesting ? null : _requestExactAlarm,
                        child: _requesting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.permGrantExactAlarm),
                      ),
                    SizedBox(height: spacing.space24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hasExactAlarm
                                ? Symbols.check_circle_sharp
                                : Symbols.warning_sharp,
                            color: _hasExactAlarm
                                ? semantic.success.color
                                : semantic.warning.color,
                          ),
                          SizedBox(width: spacing.space8),
                          Text(_hasExactAlarm
                              ? l10n.permGranted
                              : l10n.permRequired),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_hasExactAlarm || !isAndroid)
                          ? () => context
                              .go(AppRoutes.onboardingNotificationPermission3)
                          : null,
                      child: Text(l10n.commonNext),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
