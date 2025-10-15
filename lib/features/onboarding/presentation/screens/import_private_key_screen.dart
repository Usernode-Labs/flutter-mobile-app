import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';

class ImportPrivateKeyScreen extends ConsumerStatefulWidget {
  const ImportPrivateKeyScreen({super.key});

  @override
  ConsumerState<ImportPrivateKeyScreen> createState() => _ImportPrivateKeyScreenState();
}

class _ImportPrivateKeyScreenState extends ConsumerState<ImportPrivateKeyScreen> {
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
    final key = _keyCtrl.text.trim();
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
        name: 'My Account',
        privateKey: _keyCtrl.text.trim(),
      );

      if (!mounted) return;

      // Check if import succeeded
      if (result == null) {
        setState(() => _processing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import account: Invalid private key or derivation error')),
        );
        return;
      }

      // Invalidate the account provider so router sees the new account
      ref.invalidate(hasAnyAccountProvider);

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
        title: 'Import from Private Key',
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
                  'Enter your private key as a 64-character hexadecimal string.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _keyCtrl,
                decoration: InputDecoration(
                  labelText: 'Private Key',
                  hintText: 'Enter 64 hex characters',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste',
                  ),
                  errorText: _keyError,
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
                autofocus: true,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_keyValid && !_processing) ? _importAccount : null,
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
