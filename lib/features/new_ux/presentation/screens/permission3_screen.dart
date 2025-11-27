import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class Permission3Screen extends StatefulWidget {
  const Permission3Screen({super.key});

  @override
  State<Permission3Screen> createState() => _Permission3ScreenState();
}

class _Permission3ScreenState extends State<Permission3Screen> {
  bool? _granted;
  bool _requesting = false;
  bool _permanentlyDenied = false; // reserved for future UI messaging

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _granted = status.isGranted;
      _permanentlyDenied = status.isPermanentlyDenied;
    });
  }

  Future<void> _requestNotifications() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final status = await Permission.notification.request();
      final isGranted = status.isGranted;
      if (!mounted) return;
      setState(() => _granted = isGranted);
      setState(() => _permanentlyDenied = status.isPermanentlyDenied);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGranted
                ? 'Notifications enabled'
                : (status.isDenied || status.isLimited)
                    ? 'Notifications denied'
                    : status.isPermanentlyDenied
                        ? 'Notifications permanently denied. Enable in Settings.'
                        : 'Notification status: $status',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Allow notifications to receive important updates. You can change this later in Settings.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_granted != true)
                        FilledButton.tonal(
                          onPressed: _requesting ? null : _requestNotifications,
                          child: _requesting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Allow notifications'),
                        ),
                      const SizedBox(height: 12),
                      if (_permanentlyDenied == true)
                        Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Notifications are currently disabled. You can enable them in Settings.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await openAppSettings();
                                // Re-check status after returning from Settings
                                if (!mounted) return;
                                await _checkInitialStatus();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      if (_granted != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _granted! ? Icons.check_circle : Icons.warning,
                              color: _granted! ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _granted! ? 'Notifications enabled' : 'Notifications disabled',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_granted == true) ? () => context.go('/newux/main') : null,
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


