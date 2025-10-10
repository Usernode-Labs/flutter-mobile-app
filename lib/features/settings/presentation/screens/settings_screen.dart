import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    final env = ref.watch(buildEnvProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Appearance',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.phone_iphone),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) {
                final v = selection.first;
                ref.read(themeModeProvider.notifier).set(v);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Cycle Theme'),
            subtitle: const Text('System → Light → Dark'),
            trailing: const Icon(Icons.color_lens_outlined),
            onTap: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'About',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
}
// ignore_for_file: deprecated_member_use
