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
    // If notifications are already enabled, advance automatically.
    if (status.isGranted && mounted) {
      context.go(AppRoutes.onboardingBatteryPermission2);
    }
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
      // If the user just enabled notifications, advance automatically.
      if (isGranted && mounted) {
        context.go(AppRoutes.onboardingBatteryPermission2);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Allow notifications to allow the app to make blocks in the background',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Android requires a visible status to allow the app to work in the background. Without it, the system will be unable to do background block production.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_granted != true) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _requesting ? null : _requestNotifications,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _requesting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Allow Notifications'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      context.go(AppRoutes.onboardingBatteryPermission2),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest, // darker gray
                    foregroundColor: theme.colorScheme.onSurface,
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
