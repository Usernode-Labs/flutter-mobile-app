import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class BatteryPermission2Screen extends StatefulWidget {
  const BatteryPermission2Screen({super.key});

  @override
  State<BatteryPermission2Screen> createState() =>
      _BatteryPermission2ScreenState();
}

class _BatteryPermission2ScreenState extends State<BatteryPermission2Screen>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _batteryOptDisabled = false;
  bool _requesting = false;
  String? _deviceManufacturer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User returned from Settings: re-check battery optimization status
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    await PlatformAlarmService.instance.initialize();
    final disabled =
        await PlatformAlarmService.instance.isBatteryOptimizationDisabled();
    final manufacturer =
        await PlatformAlarmService.instance.getDeviceManufacturer();
    if (!mounted) return;
    setState(() {
      _batteryOptDisabled = disabled;
      _deviceManufacturer = manufacturer;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permBatteryTitle)),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header and status text
                    Row(
                      children: [
                        Icon(
                          Icons.battery_full,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          l10n.permBatteryTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.permBatteryWhyMatters,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAndroid
                          ? l10n.permBatteryAndroidExplanation
                          : l10n.permBatteryIosExplanation,
                    ),
                    if (isAndroid && !_batteryOptDisabled) ...[
                      // small box, Impact of battery optimization:
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.permBatteryImpact,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l10n.permBatteryWarning),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(l10n.permBatteryOptimized),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isAndroid && !_batteryOptDisabled) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _requesting
                            ? null
                            : () async {
                                setState(() => _requesting = true);
                                try {
                                  await PlatformAlarmService.instance
                                      .openBatteryOptimizationSettings();
                                  if (!mounted) return;
                                  await _checkStatus();
                                } finally {
                                  if (mounted)
                                    setState(() => _requesting = false);
                                }
                              },
                        icon: const Icon(Icons.settings),
                        label: _requesting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.permOpenBatterySettings),
                      ),
                    ],
                    if (isAndroid &&
                        _deviceManufacturer != null &&
                        ['xiaomi', 'samsung', 'oppo', 'oneplus']
                            .contains(_deviceManufacturer!.toLowerCase())) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.permBatteryDeviceWarning(
                                    _deviceManufacturer!),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _batteryOptDisabled
                                ? Icons.check_circle
                                : Icons.warning,
                            color: _batteryOptDisabled
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(_batteryOptDisabled
                              ? l10n.permBatteryOptDisabled
                              : l10n.permBatteryOptEnabled),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: (_batteryOptDisabled || !isAndroid)
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
