import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';

class AccountModeSelectionScreen extends StatefulWidget {
  const AccountModeSelectionScreen({super.key});

  @override
  State<AccountModeSelectionScreen> createState() =>
      _AccountModeSelectionScreenState();
}

class _AccountModeSelectionScreenState
    extends State<AccountModeSelectionScreen> {
  bool _generatingMnemonic = false;

  Future<void> _navigateToCreateNew() async {
    setState(() => _generatingMnemonic = true);
    try {
      // Generate mnemonic before navigating using Rust backend
      Log.d('ONBOARDING', 'Generating seed phrase via Rust backend...');
      final words = seedPhraseGenerate();
      final mnemonic = words.join(' ');
      Log.d('ONBOARDING', 'Seed phrase generated successfully (${words.length} words)');
      if (!mounted) return;
      setState(() => _generatingMnemonic = false);

      // Navigate using GoRouter with mnemonic as URL parameter
      final encodedMnemonic = Uri.encodeComponent(mnemonic);
      context.go('/create-new-account?mnemonic=$encodedMnemonic');
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingMnemonic = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate recovery phrase: $e')),
      );
    }
  }

  void _navigateToImportSeed() {
    context.go('/import-seed-phrase');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const AppAppBar(
          title: 'Account Setup',
          automaticallyImplyLeading: false,
          showNotifications: false,
          showNodeStatus: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Up Your Account',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create or import your private and public keys to start using the Usernode blockchain. These keys are your digital identity for all blockchain operations.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _ModeCard(
                  icon: Icons.add_circle_outline,
                  title: 'Create New Account',
                  subtitle: 'Creates a new wallet with a secure recovery phrase you\'ll need to save.',
                  loading: _generatingMnemonic,
                  onTap: _generatingMnemonic ? null : _navigateToCreateNew,
                ),
                const SizedBox(height: 12),

                _ModeCard(
                  icon: Icons.file_download_outlined,
                  title: 'Import from Seed Phrase',
                  subtitle: 'Restore your wallet using your existing 12 or 24-word recovery phrase.',
                  onTap: _navigateToImportSeed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.surfaceContainerHigh,
                foregroundColor: colorScheme.onSurfaceVariant,
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ), 
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
