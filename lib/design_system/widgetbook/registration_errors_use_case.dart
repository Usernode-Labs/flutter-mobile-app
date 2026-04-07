import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

// ---------------------------------------------------------------------------
// Mock strings — widgetbook has no localization delegates, so we hardcode
// the English strings here (matching app_en.arb).
// ---------------------------------------------------------------------------

const _kContactLabel = 'Discord, Email, or Telegram';
const _kContactHint = '@username or name@example.com';
const _kCodeLabel = 'Activation Code';
const _kCodeHint = 'Enter your code';
const _kSubmit = 'Verify Code';
const _kTitle = 'Verify access';
const _kSubtitle =
    'Use the username/registration code that has been shared with you. '
    'Username must be typed exactly as it appears in the registration email.';
const _kVersion = 'v1.4.2 (210)';

// Field errors — shown as errorText under the TextField
const _kUsernameEmpty = 'Please enter your username.';
const _kCodeEmpty = 'Please enter your activation code.';

// Form-level errors — shown as red text above the CTA
const _kApiEventInactive =
    'Registration is currently closed. If you received an invite, please contact support.';
const _kApiNotFound =
    'Username not found or registration code invalid. Please double-check both fields and try again.';
const _kApiCodeUsed =
    'This registration code has already been used. If this is your code, try re-entering your exact username.';
const _kApiValidation =
    'Please fill in both your username and registration code.';
const _kApiGeneric =
    'Registration failed. Please try again or contact support.';
const _kKeyDerivationFailed =
    'Account setup failed. Please try again or contact support.';
const _kStorageFailed =
    'Could not save account securely. Please check device storage and try again.';
const _kTimeoutError =
    'Connection timed out. Please check your internet and try again.';
const _kNetworkError =
    'Could not reach the server. Please check your internet and try again.';
const _kUnexpectedError =
    'An unexpected error occurred. Please try again or contact support.';

// Stale registration strings
const _kStaleBannerBody =
    'Your registration may be from a previous season. Blocks produced with old credentials won\'t earn points.';
const _kStaleTitle = 'Registration Expired';
const _kStaleBody =
    'Your registration is from a previous season. Blocks produced with old credentials '
    'won\'t earn points. Please re-register to participate in the current season.';
const _kStaleAction = 'Re-register';

WidgetbookComponent registrationErrorsComponent() {
  return WidgetbookComponent(
    name: 'Registration Form',
    useCases: [
      _playground(),
      _allFieldErrors(),
      _allFormErrors(),
      _staleBanner(),
      _staleScreen(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Error scenario enum
// ---------------------------------------------------------------------------

enum _Scenario {
  none('No error — idle', null, null),
  loading('Loading — submitting', null, null),
  fieldContact('Field: username empty', _kUsernameEmpty, null),
  fieldCode('Field: code empty', null, _kCodeEmpty),
  api403('API 403 — registration closed', null, _kApiEventInactive),
  api404('API 404 — username/code invalid', null, _kApiNotFound),
  api409('API 409 — code already used', null, _kApiCodeUsed),
  api422('API 422 — validation error', null, _kApiValidation),
  api5xx('API 5xx — server error', null, _kApiGeneric),
  keyDerivation('FFI — key derivation failed', null, _kKeyDerivationFailed),
  secureStorage('Storage — secure storage failed', null, _kStorageFailed),
  timeout('Network — timeout', null, _kTimeoutError),
  noConnection('Network — no connection', null, _kNetworkError),
  unexpected('Catch-all — unexpected error', null, _kUnexpectedError);

  const _Scenario(this.label, this.contactError, this.formError);
  final String label;

  /// Non-null → shown as errorText under the contact TextField
  final String? contactError;

  /// Non-null → shown as red text above the CTA button
  final String? formError;

  bool get isLoading => this == _Scenario.loading;
}

// ---------------------------------------------------------------------------
// Shared form preview widget
// ---------------------------------------------------------------------------

class _RegistrationFormPreview extends StatelessWidget {
  const _RegistrationFormPreview({
    this.contactError,
    this.codeError,
    this.formError,
    this.isLoading = false,
    this.contactValue = '',
    this.codeValue = '',
  });

  final String? contactError;
  final String? codeError;
  final String? formError;
  final bool isLoading;
  final String contactValue;
  final String codeValue;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  _kVersion,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(height: spacing.space16),
              Text(
                _kTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
              SizedBox(height: spacing.space24),
              Text(
                _kSubtitle,
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
                        controller: TextEditingController(text: contactValue),
                        decoration: InputDecoration(
                          labelText: _kContactLabel,
                          hintText: _kContactHint,
                          errorText: contactError,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: spacing.space16),
                      TextField(
                        controller: TextEditingController(text: codeValue),
                        decoration: InputDecoration(
                          labelText: _kCodeLabel,
                          hintText: _kCodeHint,
                          errorText: codeError,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ),
                ),
              ),
              if (formError != null) ...[
                SizedBox(height: spacing.space8),
                Text(
                  formError!,
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
                  label: _kSubmit,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  isLoading: isLoading,
                  onTap: isLoading ? null : () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playground — knob-driven scenario picker
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final scenario = context.knobs.object.dropdown<_Scenario>(
        label: 'Scenario',
        options: _Scenario.values,
        initialOption: _Scenario.none,
        labelBuilder: (s) => s.label,
      );
      final contactValue = context.knobs.string(
        label: 'Username value',
        initialValue: '',
      );
      final codeValue = context.knobs.string(
        label: 'Code value',
        initialValue: '',
      );

      return _RegistrationFormPreview(
        contactError: scenario.contactError,
        codeError: scenario == _Scenario.fieldCode ? _kCodeEmpty : null,
        formError: scenario.formError,
        isLoading: scenario.isLoading,
        contactValue: contactValue,
        codeValue: codeValue,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// All field error states — inline errorText under each field
// ---------------------------------------------------------------------------

WidgetbookUseCase _allFieldErrors() {
  return WidgetbookUseCase(
    name: 'Field Errors',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(spacing.space16),
            children: [
              Text(
                'Inline field validation errors',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'Shown as errorText under the offending field. '
                'Clears on next keystroke.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: spacing.space24),
              Text('Username empty', style: theme.textTheme.labelMedium),
              SizedBox(height: spacing.space8),
              const SizedBox(
                height: 480,
                child: _RegistrationFormPreview(
                  contactError: _kUsernameEmpty,
                ),
              ),
              SizedBox(height: spacing.space32),
              Text('Activation code empty', style: theme.textTheme.labelMedium),
              SizedBox(height: spacing.space8),
              const SizedBox(
                height: 480,
                child: _RegistrationFormPreview(
                  contactValue: 'exjobless',
                  codeError: _kCodeEmpty,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// All form-level error states — red text above the CTA
// ---------------------------------------------------------------------------

final _formErrorScenarios = [
  (
    'API 403 — Registration closed',
    _kApiEventInactive,
    'myusername',
    'CODE123'
  ),
  ('API 404 — Username/code invalid', _kApiNotFound, 'wronguser', 'BADCODE'),
  ('API 409 — Code already used', _kApiCodeUsed, 'peterkrulis', 'ABC123'),
  ('API 422 — Validation error', _kApiValidation, '', ''),
  ('API 5xx — Server error', _kApiGeneric, 'myusername', 'CODE123'),
  (
    'FFI — Key derivation failed',
    _kKeyDerivationFailed,
    'myusername',
    'CODE123'
  ),
  ('Storage — Secure storage failed', _kStorageFailed, 'myusername', 'CODE123'),
  ('Network — Timeout', _kTimeoutError, 'myusername', 'CODE123'),
  ('Network — No connection', _kNetworkError, 'myusername', 'CODE123'),
  ('Catch-all — Unexpected', _kUnexpectedError, 'myusername', 'CODE123'),
];

WidgetbookUseCase _allFormErrors() {
  return WidgetbookUseCase(
    name: 'Form Errors',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(spacing.space16),
            children: [
              Text(
                'Form-level errors above CTA',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                'Shown in colorScheme.error below the fields and above the '
                'button. Persists until next submit attempt.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              for (final (label, message, contact, code)
                  in _formErrorScenarios) ...[
                SizedBox(height: spacing.space32),
                Text(label, style: theme.textTheme.labelMedium),
                SizedBox(height: spacing.space8),
                SizedBox(
                  height: 520,
                  child: _RegistrationFormPreview(
                    contactValue: contact,
                    codeValue: code,
                    formError: message,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Stale Registration Banner — interactive preview
// ---------------------------------------------------------------------------

WidgetbookUseCase _staleBanner() {
  return WidgetbookUseCase(
    name: 'Stale Banner',
    builder: (context) {
      final dismissed = context.knobs.boolean(
        label: 'Dismissed',
        initialValue: false,
      );
      final stale = context.knobs.boolean(
        label: 'Registration is Stale',
        initialValue: true,
      );

      return _StaleBannerPreview(dismissed: dismissed, stale: stale);
    },
  );
}

class _StaleBannerPreview extends StatelessWidget {
  const _StaleBannerPreview({required this.dismissed, required this.stale});
  final bool dismissed;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: Column(
        children: [
          if (stale && !dismissed)
            MaterialBanner(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.space16,
                vertical: spacing.space12,
              ),
              leading: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
              ),
              content: Text(
                _kStaleBannerBody,
                style: theme.textTheme.bodySmall,
              ),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Dismiss'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(_kStaleAction),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: Center(
              child: Text(
                stale && !dismissed
                    ? 'Home screen content below banner'
                    : dismissed
                        ? 'Banner dismissed — home screen only'
                        : 'Registration is current — no banner',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stale Registration Screen — full blocking screen preview
// ---------------------------------------------------------------------------

WidgetbookUseCase _staleScreen() {
  return WidgetbookUseCase(
    name: 'Stale Screen (Hard Mode)',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(spacing.space24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                SizedBox(height: spacing.space24),
                Text(
                  _kStaleTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.space16),
                Text(
                  _kStaleBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Button(
                  label: _kStaleAction,
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () {},
                ),
                SizedBox(height: spacing.space16),
              ],
            ),
          ),
        ),
      );
    },
  );
}
