import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
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
            title: Text(l10n.settingsLanguage),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsLanguageEnglish,
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
                  title: Text(l10n.settingsLanguage),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: Text(l10n.settingsLanguageEnglish),
                        trailing: const Icon(Icons.check),
                        onTap: () => Navigator.pop(ctx),
                      ),
                      ListTile(
                        title: Text(l10n.settingsLanguageFrench),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.settingsLanguageComingSoon)),
                          );
                        },
                      ),
                      ListTile(
                        title: Text(l10n.settingsLanguageSpanish),
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.settingsLanguageComingSoon)),
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
            leading: Icon(Icons.widgets, color: colorScheme.primary),
            title: Text(l10n.settingsBackgroundBlockProduction),
            subtitle: Text(l10n.settingsBackgroundBlockProductionSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.push('/background-production-settings');
            },
          ),
          const Divider(),

          // About Section
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.settingsAbout,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            title: Text(l10n.settingsBuildInfo),
            trailing: const Icon(Icons.info_outline),
            onTap: () {
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
                      const Divider(height: 16),
                      Text(l10n.drawerP2pPeerId),
                      SelectableText(
                        ref.watch(nodeStatusProvider).value?.peerId ??
                            'Not available',
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
            },
          ),
        ],
      ),
    );
  }
}
// ignore_for_file: deprecated_member_use
