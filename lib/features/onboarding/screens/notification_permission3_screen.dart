import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class NotificationPermission3Screen extends ConsumerStatefulWidget {
  const NotificationPermission3Screen({super.key});

  @override
  ConsumerState<NotificationPermission3Screen> createState() =>
      _NotificationPermission3ScreenState();
}

class _NotificationPermission3ScreenState
    extends ConsumerState<NotificationPermission3Screen> {
  bool? _granted;
  bool _requesting = false;
  bool _permanentlyDenied = false;

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
    final l10n = AppLocalizations.of(context);
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
                ? l10n.permNotificationsEnabled
                : (status.isDenied || status.isLimited)
                    ? l10n.permNotificationsDenied
                    : status.isPermanentlyDenied
                        ? l10n.permNotificationsPermanentlyDenied
                        : l10n.permNotificationStatus(status.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.permNotificationsTitle)),
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
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          l10n.permNotificationsExplanation,
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.permAllowNotifications),
                        ),
                      const SizedBox(height: 12),
                      if (_permanentlyDenied == true)
                        Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                l10n.permNotificationsDisabledMessage,
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
                              child: Text(l10n.permOpenSettings),
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
                              _granted!
                                  ? l10n.permNotificationsEnabled
                                  : l10n.permNotificationsDisabled,
                              style: const TextStyle(
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
                  onPressed: (_granted == true)
                      ? () async {
                          await markOnboardingComplete();
                          ref.invalidate(hasCompletedOnboardingProvider);
                          if (!context.mounted) return;
                          context.go(AppRoutes.home);
                        }
                      : null,
                  child: Text(l10n.commonFinish),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
