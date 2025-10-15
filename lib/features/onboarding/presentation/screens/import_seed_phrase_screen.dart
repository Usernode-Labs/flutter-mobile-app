import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class ImportSeedPhraseScreen extends ConsumerStatefulWidget {
  const ImportSeedPhraseScreen({super.key});

  @override
  ConsumerState<ImportSeedPhraseScreen> createState() => _ImportSeedPhraseScreenState();
}

class _ImportSeedPhraseScreenState extends ConsumerState<ImportSeedPhraseScreen> {
  final _seedCtrl = TextEditingController();
  String? _seedError;
  bool _seedValid = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _seedCtrl.addListener(_validateSeed);
  }

  @override
  void dispose() {
    _seedCtrl.removeListener(_validateSeed);
    _seedCtrl.dispose();
    super.dispose();
  }

  void _validateSeed() {
    final phrase = _normalizeMnemonic(_seedCtrl.text);
    bool valid = phrase.isNotEmpty && bip39.validateMnemonic(phrase);
    String? error;
    if (_seedCtrl.text.trim().isNotEmpty && !valid) {
      error = 'Invalid BIP39 seed phrase';
    }
    setState(() {
      _seedValid = valid;
      _seedError = error;
    });
  }

  String _normalizeMnemonic(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _seedCtrl.text = data!.text!;
    }
  }

  Future<void> _importAccount() async {
    if (!_seedValid || _processing) return;

    setState(() => _processing = true);

    try {
      final repo = await AccountsRepository.create();
      final result = await repo.importFromMnemonic(
        name: 'My Account',
        mnemonic: _normalizeMnemonic(_seedCtrl.text),
      );

      if (!mounted) return;

      // Check if import succeeded
      if (result == null) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import account: Invalid seed phrase or derivation error')),
        );
        return;
      }

      // Invalidate the account provider so router sees the new account
      ref.invalidate(hasAnyAccountProvider);

      // Start backend immediately (doesn't require widget to be mounted)
      Log.d('IMPORT_SEED', 'Starting backend for imported account...');
      final backendStarted = await RustBackendService.instance.startForActiveAccount();
      Log.d('IMPORT_SEED', 'Backend start result: $backendStarted');

      // Small delay to ensure provider refreshes before navigation
      await Future.delayed(const Duration(milliseconds: 150));

      // Check if widget is still mounted before navigation
      if (!mounted) return;

      // Navigate to home - router will handle redirect
      context.go('/main/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import account: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Import from Seed Phrase',
        showNotifications: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                controller: _seedCtrl,
                decoration: InputDecoration(
                  labelText: 'Recovery Phrase',
                  hintText: 'word1 word2 word3 ...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste',
                  ),
                  errorText: _seedError,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.done,
                autofocus: true,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_seedValid && !_processing) ? _importAccount : null,
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
          ),
        ),
      ),
    );
  }
}
