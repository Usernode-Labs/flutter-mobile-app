import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/onboarding/data/registration_flow.dart';
import 'package:crypto_mobile_app/features/onboarding/data/repositories/registration_repository.dart';

final _log = LoggingService.instance.withTag('usernode/ParticipantRecovery');

/// Shows the participant-recovery dialog over the current route.
///
/// Triggered (from the app shell) when a registered user has no persisted
/// `participant_id`. Collects the Discord handle + registration code and
/// re-registers via [registerAndApply], which re-persists the participant ID.
Future<void> showParticipantRecoveryDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const ParticipantRecoveryDialog(),
  );
}

class ParticipantRecoveryDialog extends ConsumerStatefulWidget {
  const ParticipantRecoveryDialog({super.key});

  @override
  ConsumerState<ParticipantRecoveryDialog> createState() =>
      _ParticipantRecoveryDialogState();
}

class _ParticipantRecoveryDialogState
    extends ConsumerState<ParticipantRecoveryDialog> {
  static const String _defaultContact =
      String.fromEnvironment('DEFAULT_REGISTRATION_CONTACT', defaultValue: '');
  static const String _defaultCode =
      String.fromEnvironment('DEFAULT_REGISTRATION_CODE', defaultValue: '');
  static final _leadingPrefixRegex = RegExp(r'^[@#]+');

  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;

  String? _contactError;
  String? _codeError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    if (_defaultContact.isNotEmpty) _contactController.text = _defaultContact;
    if (_defaultCode.isNotEmpty) _codeController.text = _defaultCode;
  }

  @override
  void dispose() {
    _contactController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    // Capture before the async gap — the dialog's context is defunct after pop.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _contactError = null;
      _codeError = null;
      _formError = null;
    });

    final contact =
        _contactController.text.trim().replaceAll(_leadingPrefixRegex, '');
    final code = _codeController.text.trim();

    if (contact.isEmpty) {
      setState(() => _contactError = l10n.registrationUsernameEmpty);
      return;
    }
    if (code.isEmpty) {
      setState(() => _codeError = l10n.registrationCodeEmpty);
      return;
    }

    setState(() => _submitting = true);
    try {
      await registerAndApply(ref: ref, contact: contact, code: code);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.participantRecoverySuccess)),
      );
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
      _log.error('Participant recovery failed', error: e);
      setState(() => _formError = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: Text(l10n.participantRecoveryTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.participantRecoveryBody,
                style: theme.textTheme.bodyMedium),
            SizedBox(height: spacing.space24),
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
              controller: _codeController,
              decoration: InputDecoration(
                labelText: l10n.importApiAccountCodeLabel,
                hintText: l10n.importApiAccountCodeHint,
                errorText: _codeError,
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _codeError = null),
            ),
            if (_formError != null) ...[
              SizedBox(height: spacing.space16),
              Text(
                _formError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.participantRecoveryLater),
          ),
          Button(
            label: l10n.participantRecoveryRestore,
            variant: ButtonVariant.primary,
            size: ButtonSize.regular,
            isLoading: _submitting,
            onTap: _onSubmit,
          ),
        ],
      ),
    );
  }
}
