import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';

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
    final env = ref.watch(buildEnvProvider);

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
              ref.watch(nodeStatusProvider).value?.peerId ?? 'Not available',
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
}
