import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

enum AccountCreationMode {
  createNew,
  importSeed,
  importPrivateKey,
}

class SingleAccountOnboardingScreen extends StatefulWidget {
  const SingleAccountOnboardingScreen({super.key});

  @override
  State<SingleAccountOnboardingScreen> createState() =>
      _SingleAccountOnboardingScreenState();
}

class _SingleAccountOnboardingScreenState
    extends State<SingleAccountOnboardingScreen> {
  AccountCreationMode _mode = AccountCreationMode.createNew;
  bool _modeSelected = false;

  // Create new mode
  bool _generating = false;
  String? _generatedMnemonic;
  bool _ackSaved = false;

  // Import seed mode
  final _importSeedCtrl = TextEditingController();
  String? _seedError;
  bool _seedValid = false;

  // Import private key mode
  final _importKeyCtrl = TextEditingController();
  String? _keyError;
  bool _keyValid = false;

  // Common
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _generateMnemonic();
    _importSeedCtrl.addListener(_validateSeed);
    _importKeyCtrl.addListener(_validateKey);
  }

  @override
  void dispose() {
    _importSeedCtrl.removeListener(_validateSeed);
    _importKeyCtrl.removeListener(_validateKey);
    _importSeedCtrl.dispose();
    _importKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateMnemonic() async {
    setState(() => _generating = true);
    try {
      final seed = bip39.generateMnemonic();
      setState(() {
        _generatedMnemonic = seed;
        _generating = false;
      });
    } catch (e) {
      setState(() {
        _generatedMnemonic = null;
        _generating = false;
      });
    }
  }

  void _validateSeed() {
    final phrase = _normalizeMnemonic(_importSeedCtrl.text);
    bool valid = phrase.isNotEmpty && bip39.validateMnemonic(phrase);
    String? error;
    if (_importSeedCtrl.text.trim().isNotEmpty && !valid) {
      error = 'Invalid BIP39 seed phrase';
    }
    setState(() {
      _seedValid = valid;
      _seedError = error;
    });
  }

  void _validateKey() {
    final key = _importKeyCtrl.text.trim();
    // Basic hex validation (64 chars for 32 bytes)
    final hexRegex = RegExp(r'^[0-9a-fA-F]{64}$');
    bool valid = hexRegex.hasMatch(key);
    String? error;
    if (key.isNotEmpty && !valid) {
      error = 'Invalid private key format (expected 64 hex characters)';
    }
    setState(() {
      _keyValid = valid;
      _keyError = error;
    });
  }

  String _normalizeMnemonic(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _pasteFromClipboard(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      controller.text = data!.text!;
    }
  }

  bool get _canProceed {
    switch (_mode) {
      case AccountCreationMode.createNew:
        return _generatedMnemonic != null && _ackSaved && !_processing;
      case AccountCreationMode.importSeed:
        return _seedValid && !_processing;
      case AccountCreationMode.importPrivateKey:
        return _keyValid && !_processing;
    }
  }

  Future<void> _complete() async {
    if (!_canProceed) return;

    setState(() => _processing = true);

    try {
      final repo = await AccountsRepository.create();
      const accountName = 'My Account';

      switch (_mode) {
        case AccountCreationMode.createNew:
          await repo.importFromMnemonic(
            name: accountName,
            mnemonic: _generatedMnemonic!,
          );
          break;
        case AccountCreationMode.importSeed:
          await repo.importFromMnemonic(
            name: accountName,
            mnemonic: _normalizeMnemonic(_importSeedCtrl.text),
          );
          break;
        case AccountCreationMode.importPrivateKey:
          await repo.importFromPrivateKey(
            name: accountName,
            privateKey: _importKeyCtrl.text.trim(),
          );
          break;
      }

      if (!mounted) return;

      // Use GoRouter for navigation - router will automatically redirect to home
      // because hasAnyAccountProvider will now return true
      context.go('/main/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: const AppAppBar(
          title: 'Account Setup',
          automaticallyImplyLeading: false,
          showNotifications: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mode selector
                Text(
                  'Choose how to set up your account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                _ModeCard(
                  icon: Icons.add_circle_outline,
                  title: 'Create New Account',
                  subtitle: 'Generate a new recovery phrase',
                  isSelected: _mode == AccountCreationMode.createNew,
                  recommended: true,
                  onTap: () => setState(() {
                    _mode = AccountCreationMode.createNew;
                    _modeSelected = true;
                  }),
                ),
                const SizedBox(height: 12),

                _ModeCard(
                  icon: Icons.file_download_outlined,
                  title: 'Import from Seed Phrase',
                  subtitle: 'Use existing 12/24-word recovery phrase',
                  isSelected: _mode == AccountCreationMode.importSeed,
                  onTap: () => setState(() {
                    _mode = AccountCreationMode.importSeed;
                    _modeSelected = true;
                  }),
                ),
                const SizedBox(height: 12),

                _ModeCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Import from Private Key',
                  subtitle: 'Use existing private key',
                  isSelected: _mode == AccountCreationMode.importPrivateKey,
                  onTap: () => setState(() {
                    _mode = AccountCreationMode.importPrivateKey;
                    _modeSelected = true;
                  }),
                ),

                // Only show content after a mode has been selected
                if (_modeSelected) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Content based on mode
                  if (_mode == AccountCreationMode.createNew)
                    _buildCreateNewContent(theme, l10n)
                  else if (_mode == AccountCreationMode.importSeed)
                    _buildImportSeedContent(theme)
                  else
                    _buildImportKeyContent(theme),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateNewContent(ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Write down your recovery phrase and store it safely. You\'ll need it to recover your account.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Your Recovery Phrase',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        if (_generating)
          const Center(child: CircularProgressIndicator())
        else if (_generatedMnemonic != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _MnemonicGrid(mnemonic: _generatedMnemonic!),
            ),
          ),

        const SizedBox(height: 24),

        Row(
          children: [
            Checkbox(
              value: _ackSaved,
              onChanged: (v) => setState(() => _ackSaved = v ?? false),
            ),
            Expanded(
              child: Text(
                'I have safely stored my recovery phrase',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canProceed ? _complete : null,
            child: _processing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Account'),
          ),
        ),
      ],
    );
  }

  Widget _buildImportSeedContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Enter your existing 12 or 24-word recovery phrase to import your account.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _importSeedCtrl,
          decoration: InputDecoration(
            labelText: 'Recovery Phrase',
            hintText: 'word1 word2 word3 ...',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () => _pasteFromClipboard(_importSeedCtrl),
              tooltip: 'Paste',
            ),
            errorText: _seedError,
          ),
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canProceed ? _complete : null,
            child: _processing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import Account'),
          ),
        ),
      ],
    );
  }

  Widget _buildImportKeyContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Enter your private key as a 64-character hexadecimal string.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: _importKeyCtrl,
          decoration: InputDecoration(
            labelText: 'Private Key',
            hintText: 'Enter 64 hex characters',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.vpn_key),
            suffixIcon: IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () => _pasteFromClipboard(_importKeyCtrl),
              tooltip: 'Paste',
            ),
            errorText: _keyError,
          ),
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _canProceed ? _complete : null,
            child: _processing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Import Account'),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool recommended;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.recommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHigh,
                foregroundColor: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                child: Icon(icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MnemonicGrid extends StatelessWidget {
  final String mnemonic;
  const _MnemonicGrid({required this.mnemonic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = mnemonic.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth > 360;
        final columns = isWide ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 4.0,
          ),
          itemCount: words.length,
          itemBuilder: (_, i) {
            final idx = i + 1;
            final w = words[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$idx',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      w,
                      style: theme.textTheme.titleMedium,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
