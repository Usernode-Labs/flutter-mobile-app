import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_provider.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  void _onVersionLongPress() {
    _showPinDialog();
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '4-digit code',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (pinController.text == AppConfig.networkSwitcherCode) {
                Navigator.of(ctx).pop(true);
              } else {
                Navigator.of(ctx).pop(false);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      _showNetworkSwitcherDialog();
    }
  }

  Future<void> _showNetworkSwitcherDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final storedNetwork = prefs.getString('network:type');
    final currentNetwork = switch (storedNetwork) {
      'internal' || 'custom' || 'testnet' => storedNetwork!,
      _ => 'testnet',
    };

    if (!mounted) return;

    final selectedNetwork = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Network Switcher'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('testnet'),
            child: ListTile(
              leading: Icon(
                currentNetwork == 'testnet'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: const Text('Testnet'),
              subtitle: const Text('Default network'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('internal'),
            child: ListTile(
              leading: Icon(
                currentNetwork == 'internal'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: const Text('Internal'),
              subtitle: const Text('Development network'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('custom'),
            child: ListTile(
              leading: Icon(
                currentNetwork == 'custom'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: const Text('Custom'),
              subtitle: const Text('static.usernodelabs.org/custom'),
            ),
          ),
        ],
      ),
    );

    if (selectedNetwork != null &&
        selectedNetwork != currentNetwork &&
        mounted) {
      await prefs.setString('network:type', selectedNetwork);
      _showRestartDialog(selectedNetwork);
    }
  }

  Future<void> _showRestartDialog(String network) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart Required'),
        content: Text(
          'Network switched to ${_networkLabel(network)}. '
          '${Platform.isIOS ? 'Please manually close and reopen the app to connect to the new network.' : 'The app will now close. Please reopen it to connect to the new network.'}',
        ),
        actions: [
          if (Platform.isIOS)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('OK'),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                SystemNavigator.pop();
              },
              child: const Text('Close App'),
            ),
        ],
      ),
    );
  }

  String _networkLabel(String network) {
    switch (network) {
      case 'internal':
        return 'Internal';
      case 'custom':
        return 'Custom';
      case 'testnet':
      default:
        return 'Testnet';
    }
  }

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
            GestureDetector(
              onLongPress: _onVersionLongPress,
              child: Text('${l10n.buildInfoVersion}: ${env.version}'),
            ),
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
