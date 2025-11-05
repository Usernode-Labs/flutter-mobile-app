// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/routing/app_router.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final env = ref.watch(buildEnvProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const AppDrawer(),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // Preferences Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.tune, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Preferences',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.language, color: colorScheme.primary),
            title: const Text('Language'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'English',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Language'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('English'),
                        trailing: const Icon(Icons.check),
                        onTap: () => Navigator.pop(ctx),
                      ),
                      ListTile(
                        title: const Text('Français'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Language support coming soon')),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('Español'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Language support coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.attach_money, color: colorScheme.primary),
            title: const Text('Currency'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'USD',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Currency'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('USD (\$)'),
                        trailing: const Icon(Icons.check),
                        onTap: () => Navigator.pop(ctx),
                      ),
                      ListTile(
                        title: const Text('EUR (€)'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Currency support coming soon')),
                          );
                        },
                      ),
                      ListTile(
                        title: const Text('GBP (£)'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Currency support coming soon')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications, color: colorScheme.primary),
            title: const Text('Notifications'),
            subtitle: const Text('Manage slot notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/notification-settings');
            },
          ),
          const Divider(),

          // Developer Section
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.code, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Developer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: colorScheme.primary),
            title: const Text('Delete Account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showDeleteAccountDialog,
          ),
          const Divider(),

          // About Section
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'About',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            title: const Text('Build Info'),
            trailing: const Icon(Icons.info_outline),
            onTap: () {
              final shortCommit = env.git.commitHash.length >= 7
                  ? env.git.commitHash.substring(0, 7)
                  : env.git.commitHash;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Build Info'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Version: ${env.version}'),
                      const SizedBox(height: 6),
                      Text('Commit: $shortCommit'),
                      const SizedBox(height: 6),
                      Text('Branch: ${env.git.branch}'),
                      const SizedBox(height: 6),
                      Text('Commit time: ${env.git.commitTime}'),
                      const Divider(height: 16),
                      Text(
                          'Rustc: ${env.rustc.version} (${env.rustc.channel})'),
                      const SizedBox(height: 6),
                      Text('LLVM: ${env.rustc.llvmVersion}'),
                      const Divider(height: 16),
                      Text('Cargo target: ${env.cargo.target}'),
                      const SizedBox(height: 6),
                      Text('Features: ${env.cargo.features}'),
                      const SizedBox(height: 6),
                      Text('Opt level: ${env.cargo.optLevel}'),
                      const SizedBox(height: 6),
                      Text('Debug: ${env.cargo.isDebug}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Close'),
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(ctx).colorScheme.error,
          size: 48,
        ),
        title: const Text('Delete All Accounts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete ALL accounts and app data. This is a complete reset.',
            ),
            const SizedBox(height: 12),
            Text(
              '⚠️ This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Make sure you have backed up all recovery phrases if you want to restore your accounts later.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete All Accounts'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      // Delete ALL accounts from storage (complete reset)
      final repo = await AccountsRepository.create();
      await repo.deleteAll();

      if (!mounted) return;

      // Invalidate the provider (backend will stop automatically via backendLifecycleProvider)
      LoggingService.instance
          .debug('Invalidating hasAnyAccountProvider', tag: 'SETTINGS');
      ref.invalidate(hasAnyAccountProvider);

      // Wait for next frame before navigating to avoid race condition
      LoggingService.instance
          .debug('Waiting for next frame...', tag: 'SETTINGS');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        LoggingService.instance
            .debug('Navigating to onboarding screen', tag: 'SETTINGS');
        context.go(AppRoutes.onboarding);

        // Show success message after navigation
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('All accounts deleted successfully')),
            );
          }
        });
      });
    } catch (e, st) {
      LoggingService.instance.error('Failed to delete account',
          tag: 'SETTINGS', error: e, stackTrace: st);
      if (!mounted) return;

      // Provide more specific error message
      String errorMessage = 'Failed to delete account';
      if (e.toString().contains('storage')) {
        errorMessage = 'Failed to delete account: Storage error';
      } else if (e.toString().contains('backend')) {
        errorMessage = 'Failed to delete account: Backend error';
      } else {
        errorMessage = 'Failed to delete account: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
// ignore_for_file: deprecated_member_use
