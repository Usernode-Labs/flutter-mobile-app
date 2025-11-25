// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/routing/app_router.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';

final _log = LoggingService.instance.withTag(LogTag.drawer);

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final routeInfo = GoRouter.of(context).routeInformationProvider.value;
    final location = routeInfo.uri.toString();
    final env = ref.watch(buildEnvProvider);

    Widget item({
      required IconData icon,
      required String label,
      String? subtitle,
      required VoidCallback onTap,
      String? matchRoute,
    }) {
      final selected =
          matchRoute != null ? location.startsWith(matchRoute) : false;
      return ListTile(
        leading: Icon(icon, color: selected ? colorScheme.primary : null),
        title: Text(
          label,
          style: selected
              ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
              : theme.textTheme.bodyLarge,
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        selected: selected,
        selectedTileColor: colorScheme.surfaceContainerLow,
        onTap: () {
          Navigator.of(context).pop(); // Close drawer
          onTap();
        },
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Usernode',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // Home
            item(
              icon: Icons.home_outlined,
              label: 'Home',
              matchRoute: '/main/home',
              onTap: () => context.go('/main/home'),
            ),

            const Divider(),

            // Settings Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Background Block Production
            item(
              icon: Icons.widgets,
              label: 'Background Production',
              subtitle: 'Configure automatic block production',
              matchRoute: '/background-production-settings',
              onTap: () => context.push('/background-production-settings'),
            ),

            const Divider(),

            // Developer Section Header
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

            // Delete Account
            ListTile(
              leading: Icon(Icons.delete_forever, color: colorScheme.primary),
              title: const Text('Delete Account'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                _showDeleteAccountDialog();
              },
            ),

            const Divider(),

            // About Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'About',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // Build Info
            ListTile(
              title: const Text('Build Info'),
              trailing: const Icon(Icons.info_outline),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                _showBuildInfoDialog(env);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBuildInfoDialog(dynamic env) {
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
            Text('Rustc: ${env.rustc.version} (${env.rustc.channel})'),
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
            const Divider(height: 16),
            Text('P2P Peer ID:'),
            SelectableText(
              RustBackendService.instance.getPeerId() ?? 'Not available',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
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
      LoggingService.instance.debug('Invalidating hasAnyAccountProvider');
      ref.invalidate(hasAnyAccountProvider);

      // Wait for next frame before navigating to avoid race condition
      _log.debug('Waiting for next frame...');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        LoggingService.instance.debug('Navigating to onboarding screen');
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
      _log.error('Failed to delete account', error: e, stackTrace: st);
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
