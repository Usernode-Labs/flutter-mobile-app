import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);

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
                  l10n.appName,
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
                l10n.settingsAbout,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

            // Build Info
            ListTile(
              title: Text(l10n.settingsBuildInfo),
              trailing: const Icon(Icons.info_outline),
              onTap: () {
                Navigator.of(context).pop(); // Close drawer
                _showBuildInfoDialog(env, l10n);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBuildInfoDialog(dynamic env, AppLocalizations l10n) {
    final shortCommit = env.git.commitHash.length >= 7
        ? env.git.commitHash.substring(0, 7)
        : env.git.commitHash;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsBuildInfo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.buildInfoVersion}: ${env.version}'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoCommit}: $shortCommit'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoBranch}: ${env.git.branch}'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoCommitTime}: ${env.git.commitTime}'),
            const Divider(height: 16),
            Text(
                '${l10n.buildInfoRustc}: ${env.rustc.version} (${env.rustc.channel})'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoLlvm}: ${env.rustc.llvmVersion}'),
            const Divider(height: 16),
            Text('${l10n.buildInfoCargoTarget}: ${env.cargo.target}'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoFeatures}: ${env.cargo.features}'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoOptLevel}: ${env.cargo.optLevel}'),
            const SizedBox(height: 6),
            Text('${l10n.buildInfoDebug}: ${env.cargo.isDebug}'),
            const Divider(height: 16),
            Text(l10n.drawerP2pPeerId),
            SelectableText(
              ref.watch(nodeStatusProvider).value?.peerId ??
                  l10n.nodeNotAvailable,
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
            child: Text(l10n.drawerClose),
          )
        ],
      ),
    );
  }
}
