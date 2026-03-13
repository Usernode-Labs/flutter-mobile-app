import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';
import 'package:crypto_mobile_app/features/onboarding/data/onboarding_providers.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

final _log = LoggingService.instance.withTag('usernode/ImportApiAccountScreen');

class OnboardingImportApiAccountScreen extends ConsumerStatefulWidget {
  const OnboardingImportApiAccountScreen({super.key});

  @override
  ConsumerState<OnboardingImportApiAccountScreen> createState() =>
      _OnboardingImportApiAccountScreenState();
}

class _OnboardingImportApiAccountScreenState
    extends ConsumerState<OnboardingImportApiAccountScreen> {
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
    final l10n = AppLocalizations.of(context);
    try {
      final contact = _contactController.text.trim();
      final activationCode = _activationCodeController.text.trim();

      final registration =
          await _registerViaApi(contact: contact, code: activationCode);

      final repo = await AccountsRepository.create();
      final result = await repo.importFromSecretKey(
        name: 'API Account',
        secretKey: registration.secretKey,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importApiAccountFailed)),
        );
        return;
      }

      // Start backend for new account
      try {
        await RustBackendService.instance.startNode();
        _log.debug('Backend started successfully');
      } catch (e, st) {
        _log.error('Failed to start backend', error: e, stackTrace: st);
      }

      // Invalidate account state so router sees new account immediately
      ref.invalidate(hasAnyAccountProvider);

      // Navigate to welcome setup screen before permission flow
      if (!mounted) return;
      ref.read(onboardingUserIdProvider.notifier).state = contact;
      context.go(AppRoutes.onboardingWelcomeSetup);
    } on RegistrationApiException catch (e) {
      if (!mounted) return;
      String message = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(l10n.importApiAccountRegistrationFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<RegistrationResult> _registerViaApi({
    required String contact,
    required String code,
  }) async {
    final repo = RegistrationRepository();
    return repo.register(registrationCode: code, identifier: contact);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: spacing.space16),
              Text(
                l10n.onboardingVerifyAccessTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(height: spacing.space24),
              Text(
                l10n.onboardingVerifyAccessSubtitle,
                style: theme.textTheme.bodyMedium,
              ),
              SizedBox(height: spacing.space32),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _contactController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: l10n.importApiAccountContactLabel,
                          hintText: l10n.importApiAccountContactHint,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: spacing.space16),
                      TextField(
                        controller: _activationCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.importApiAccountCodeLabel,
                          hintText: l10n.importApiAccountCodeHint,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: spacing.space24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: l10n.importApiAccountSubmit,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  isLoading: _submitting,
                  onTap: _onSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
