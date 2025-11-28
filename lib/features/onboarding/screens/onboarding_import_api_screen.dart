import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';

class NewUxOnboardingImportApiScreen extends ConsumerStatefulWidget {
  const NewUxOnboardingImportApiScreen({super.key});

  @override
  ConsumerState<NewUxOnboardingImportApiScreen> createState() =>
      _NewUxOnboardingImportApiScreenState();
}

class _NewUxOnboardingImportApiScreenState
    extends ConsumerState<NewUxOnboardingImportApiScreen> {
  static const String _defaultContact =
      String.fromEnvironment('DEFAULT_REGISTRATION_CONTACT', defaultValue: '');
  static const String _defaultCode =
      String.fromEnvironment('DEFAULT_REGISTRATION_CODE', defaultValue: '');

  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _activationCodeController =
      TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (_defaultContact.isNotEmpty) {
      _contactController.text = _defaultContact;
    }
    if (_defaultCode.isNotEmpty) {
      _activationCodeController.text = _defaultCode;
    }
  }

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
            .debug('Backend started successfully', tag: 'NEW_UX_IMPORT_API');
      } catch (e) {
        LoggingService.instance.error('Failed to start backend',
            tag: 'NEW_UX_IMPORT_API', error: e);
      }

      // Invalidate account state so router sees new account immediately
      ref.invalidate(hasAnyAccountProvider);

      // Navigate to New UX permission 1
      if (!mounted) return;
      context.go('/onboarding/permission1');
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
        registrationCode: code, identifier: contact);
    return result.secretKeyHex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppAppBar(
        title: 'Import Account',
        showNodeStatus: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: const FractionalOffset(0.5, 0.33),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _contactController,
                            decoration: const InputDecoration(
                              labelText: 'Discord, Email, or Telegram',
                              hintText: '@username or name@example.com',
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _activationCodeController,
                            decoration: const InputDecoration(
                              labelText: 'Activation Code',
                              hintText: 'Enter your code',
                            ),
                            textInputAction: TextInputAction.done,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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


