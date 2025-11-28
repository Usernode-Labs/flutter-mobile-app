import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

class Permission2Screen extends StatefulWidget {
  const Permission2Screen({super.key});

  @override
  State<Permission2Screen> createState() => _Permission2ScreenState();
}

class _Permission2ScreenState extends State<Permission2Screen>
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
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Optimization')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header and status text copied from BackgroundProductionSettingsScreen
                  Row(
                    children: [
                      Icon(
                        Icons.battery_full,
                        color:
                            Colors.green,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Battery Optimization',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Why this matters',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAndroid
                        ? 'Android\'s battery saver can delay or skip alarms to save power. Disabling battery optimization for this app ensures your wake-up alarms fire on time when blocks are scheduled to be produced.'
                        : 'This step applies to Android devices.',
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
                            const Text(
                              'Impact of battery optimization:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Alarms may be delayed 1–60 seconds, or skipped entirely.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'With optimization disabled, alarms fire precisely when scheduled.',
                                  ),
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
                                if (mounted) setState(() => _requesting = false);
                              }
                            },
                      icon: const Icon(Icons.settings),
                      label: _requesting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Open Battery Settings'),
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
                              '$_deviceManufacturer devices require additional settings. Tap Open Battery Settings for guidance.',
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
                          color:
                              _batteryOptDisabled ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(_batteryOptDisabled
                            ? 'Battery optimization disabled'
                            : 'Battery optimization enabled'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (_batteryOptDisabled || !isAndroid)
                        ? () => context.go('/onboarding/permission3')
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
    );
  }
}


