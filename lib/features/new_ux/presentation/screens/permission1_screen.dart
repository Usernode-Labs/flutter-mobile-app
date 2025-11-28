import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';

class Permission1Screen extends StatefulWidget {
  const Permission1Screen({super.key});

  @override
  State<Permission1Screen> createState() => _Permission1ScreenState();
}

class _Permission1ScreenState extends State<Permission1Screen> {
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
    setState(() {
      _hasExactAlarm = has;
      _checking = false;
    });
  }

  Future<void> _requestExactAlarm() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final granted =
          await PlatformAlarmService.instance.requestExactAlarmOnly();
      if (!mounted) return;
      setState(() => _hasExactAlarm = granted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Exact alarm permission granted'
                : 'Please enable exact alarms in Settings',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      appBar: AppBar(title: const Text('Exact Alarms')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Why exact alarms are required',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAndroid
                        ? 'Android restricts apps from waking the device at precise times unless explicitly allowed. Without this permission, alarms may be delayed by up to 10 minutes, causing missed blocks.\n\nDepending on your device, this permission may already be granted.'
                        : 'This step is primarily for Android devices. You can continue.',
                  ),
                  const SizedBox(height: 16),
                  if (isAndroid && !_hasExactAlarm)
                    FilledButton.tonal(
                      onPressed: _requesting ? null : _requestExactAlarm,
                      child: _requesting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Grant exact alarm permission'),
                    ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _hasExactAlarm ? Icons.check_circle : Icons.warning,
                          color: _hasExactAlarm ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(_hasExactAlarm
                            ? 'Permission granted'
                            : 'Permission required'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (_hasExactAlarm || !isAndroid)
                        ? () => context.go('/newux/onboarding/permission2')
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
    );
  }
}


