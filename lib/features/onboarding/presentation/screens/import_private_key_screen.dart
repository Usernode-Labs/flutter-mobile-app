import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';

class ImportPrivateKeyScreen extends ConsumerStatefulWidget {
  const ImportPrivateKeyScreen({super.key});

  @override
  ConsumerState<ImportPrivateKeyScreen> createState() =>
      _ImportPrivateKeyScreenState();
}

class _ImportPrivateKeyScreenState
    extends ConsumerState<ImportPrivateKeyScreen> {
  final _keyCtrl = TextEditingController();
  String? _keyError;
  bool _keyValid = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _keyCtrl.addListener(_validateKey);
  }

  @override
  void dispose() {
    _keyCtrl.removeListener(_validateKey);
    _keyCtrl.dispose();
    super.dispose();
  }

  void _validateKey() {
    final key = _normalizeHex(_keyCtrl.text);
    bool valid = false;
    String? error;

    if (key.isNotEmpty) {
      // Check hex format and length (64 chars = 32 bytes, or 66 with 0x prefix)
      final hexPattern = RegExp(r'^(0x)?[0-9a-fA-F]{64}$');
      if (!hexPattern.hasMatch(key)) {
        error =
            'Invalid format: Must be 64 hex characters (with optional 0x prefix)';
      } else {
        // Validate by attempting to derive account from private key using Rust backend
        try {
          accountFromPrivateKey(privateKeyHex: key);
          valid = true;
        } catch (e) {
          error = 'Invalid private key';
        }
      }
    }

    setState(() {
      _keyValid = valid;
      _keyError = error;
    });
  }

  String _normalizeHex(String input) {
    return input.trim();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _keyCtrl.text = data!.text!;
    }
  }

  Future<void> _importAccount() async {
    if (!_keyValid || _processing) return;

    setState(() => _processing = true);

    try {
      final repo = await AccountsRepository.create();
      final result = await repo.importFromPrivateKey(
        name: 'Imported Account',
        privateKeyHex: _normalizeHex(_keyCtrl.text),
      );

      if (!mounted) return;

      // Check if import succeeded
      if (result == null) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to import account: Invalid private key')),
        );
        return;
      }

      LoggingService.instance.debug('Import successful, starting backend',
          tag: 'IMPORT_PRIVATE_KEY');

      // Invalidate provider to update router state
      ref.invalidate(hasAnyAccountProvider);

      // Start backend for new account
      try {
        await RustBackendService.instance.startNode();
        LoggingService.instance
            .debug('Backend started successfully', tag: 'IMPORT_PRIVATE_KEY');
      } catch (e) {
        LoggingService.instance.error('Failed to start backend',
            tag: 'IMPORT_PRIVATE_KEY', error: e);
      }

      // Navigate to identity verification screen
      if (!mounted) return;
      context.go('/identity-verification?accountId=${result.id}');
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
        title: 'Import from Private Key',
        showNodeStatus: false,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your private key (hex format) to import your account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Never share your private key with anyone!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keyCtrl,
                decoration: InputDecoration(
                  labelText: 'Private Key (Hex)',
                  hintText: '0x... or 64 hex characters',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste',
                  ),
                  errorText: _keyError,
                ),
                textInputAction: TextInputAction.done,
                autofocus: true,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (_keyValid && !_processing) ? _importAccount : null,
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
