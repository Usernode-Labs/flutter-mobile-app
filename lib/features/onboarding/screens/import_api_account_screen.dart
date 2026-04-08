import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';
import 'package:crypto_mobile_app/features/onboarding/data/onboarding_providers.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  static final _leadingPrefixRegex = RegExp(r'^[@#]+');

  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _activationCodeController =
      TextEditingController();
  bool _submitting = false;
  String _versionLabel = '';

  String? _contactError;
  String? _codeError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    if (_defaultContact.isNotEmpty) {
      _contactController.text = _defaultContact;
    }
    if (_defaultCode.isNotEmpty) {
      _activationCodeController.text = _defaultCode;
    }
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _versionLabel = 'v${info.version} (${info.buildNumber})');
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
    final l10n = AppLocalizations.of(context);

    // Clear all errors before each attempt
    setState(() {
      _contactError = null;
      _codeError = null;
      _formError = null;
    });

    // Client-side input validation
    final contact =
        _contactController.text.trim().replaceAll(_leadingPrefixRegex, '');
    final activationCode = _activationCodeController.text.trim();

    if (contact.isEmpty) {
      setState(() => _contactError = l10n.registrationUsernameEmpty);
      return;
    }
    if (activationCode.isEmpty) {
      setState(() => _codeError = l10n.registrationCodeEmpty);
      return;
    }

    setState(() => _submitting = true);
    try {
      final registration =
          await _registerViaApi(contact: contact, code: activationCode);

      final repo = await AccountsRepository.create();
      await repo.importFromSecretKey(
        name: 'API Account',
        secretKey: registration.secretKey,
      );

      if (!mounted) return;

      // Persist season context so cold-start can detect staleness.
      // With season continuity, registration is at the season level —
      // don't persist the season-phase eventId as a user selection.
      if (registration.seasonId != null) {
        await LeaderboardBootstrap.persistSeasonEvent(SeasonEventContext(
          seasonId: registration.seasonId,
          seasonName: registration.seasonName,
        ));
      }

      // Start backend for new account
      var backendFailed = false;
      try {
        await RustBackendService.instance.startNode();
        _log.debug('Backend started successfully');
      } catch (e, st) {
        _log.error('Failed to start backend', error: e, stackTrace: st);
        backendFailed = true;
      }

      // Reset stale registration state (important for re-registration flow)
      ref.read(registrationFreshnessProvider.notifier).state =
          RegistrationFreshness.unknown;

      // Invalidate account state so router sees new account immediately
      ref.invalidate(hasAnyAccountProvider);

      // Navigate to welcome setup screen before permission flow
      if (!mounted) return;

      if (backendFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importApiAccountBackendStartFailed)),
        );
      }

      ref.read(onboardingUserIdProvider.notifier).state = contact;
      context.go(AppRoutes.onboardingWelcomeSetup);
    } on RegistrationApiException catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.message);
    } on AccountImportException catch (e) {
      if (!mounted) return;
      final message = switch (e.failure) {
        AccountImportFailure.keyDerivation =>
          l10n.importApiAccountKeyDerivationFailed,
        AccountImportFailure.secureStorage =>
          l10n.importApiAccountStorageFailed,
      };
      setState(() => _formError = message);
    } catch (e) {
      if (!mounted) return;
      final message = switch (e) {
        TimeoutException() => l10n.registrationTimeoutError,
        SocketException() => l10n.registrationNetworkError,
        http.ClientException() => l10n.registrationNetworkError,
        _ => l10n.registrationUnexpectedError,
      };
      _log.error('Registration failed with unexpected error', error: e);
      setState(() => _formError = message);
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
              if (_versionLabel.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    _versionLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
                          errorText: _contactError,
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() => _contactError = null),
                      ),
                      SizedBox(height: spacing.space16),
                      TextField(
                        controller: _activationCodeController,
                        decoration: InputDecoration(
                          labelText: l10n.importApiAccountCodeLabel,
                          hintText: l10n.importApiAccountCodeHint,
                          errorText: _codeError,
                        ),
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() => _codeError = null),
                      ),
                    ],
                  ),
                ),
              ),
              if (_formError != null) ...[
                SizedBox(height: spacing.space8),
                Text(
                  _formError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
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
