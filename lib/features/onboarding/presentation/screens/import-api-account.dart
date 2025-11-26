import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

class ImportAPIAccountScreen extends ConsumerStatefulWidget {

  const ImportAPIAccountScreen({
    super.key,
  });

  @override
  ConsumerState<ImportAPIAccountScreen> createState() => _ImportAPIAccountScreenState();
}

class _ImportAPIAccountScreenState extends ConsumerState<ImportAPIAccountScreen> {
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _activationCodeController =
      TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _contactController.dispose();
    _activationCodeController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final contact = _contactController.text.trim();
      final activationCode = _activationCodeController.text.trim();
      // Placeholder API call: simulate fetching a private key for given contact/code
      final privateKeyHex =
          await _requestPrivateKeyFromApiPlaceholder(contact, activationCode);

      final repo = await AccountsRepository.create();
      final result = await repo.importFromPrivateKey(
        name: 'API Account',
        privateKeyHex: privateKeyHex,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import account from API')),
        );
        return;
      }

      // Start backend for new account
      try {
        await RustBackendService.instance.startNode();
        LoggingService.instance
            .debug('Backend started successfully', tag: 'IMPORT_API_ACCOUNT');
      } catch (e) {
        LoggingService.instance.error('Failed to start backend',
            tag: 'IMPORT_API_ACCOUNT', error: e);
      }

      // Invalidate account state so router sees new account immediately
      ref.invalidate(hasAnyAccountProvider);

      // Navigate to identity verification screen
      if (!mounted) return;
      context.go('/identity-verification?accountId=${result.id}');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String> _requestPrivateKeyFromApiPlaceholder(
      String contact, String code) async
      {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    // Generate a valid account using Rust, then return its private key
    final words = seedPhraseGenerate(wordCount: 12);
    final export = accountFromSeed(
      phrase: words.join(' '),
      passphrase: null,
      index: 0,
    );
    return export.secretKeyHex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(
        title: 'Import Pre-configured Account',
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Discord, Email, or Telegram',
                  hintText: '@username or name@example.com',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _activationCodeController,
                decoration: const InputDecoration(
                  labelText: 'Activation Code',
                  hintText: 'Enter your code',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _onSubmit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}