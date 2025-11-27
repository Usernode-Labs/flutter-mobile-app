import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/wallet/data/repositories/accounts_repository.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';

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
      final privateKeyHex = await _requestPrivateKeyFromApi(contact, activationCode);

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
    } on RegistrationApiException catch (e) {
      if (!mounted) return;
      String message = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String> _requestPrivateKeyFromApi(String contact, String code) async {
    final repo = RegistrationRepository();
    final result = await repo.register(
      registrationCode: code,
      identifier: contact);
    return result.secretKeyHex;
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