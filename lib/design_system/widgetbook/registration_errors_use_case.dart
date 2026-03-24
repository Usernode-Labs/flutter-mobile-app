import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';

// ---------------------------------------------------------------------------
// Mock strings — widgetbook has no localization delegates, so we hardcode
// the English strings here (matching app_en.arb).
// ---------------------------------------------------------------------------

const _kKeyDerivationFailed =
    'Account setup failed. Please try again or contact support.';
const _kStorageFailed =
    'Could not save account securely. Please check device storage and try again.';
const _kBackendStartFailed =
    'Account created, but node startup failed. The app will retry automatically.';
const _kTimeoutError =
    'Connection timed out. Please check your internet and try again.';
const _kNetworkError =
    'Could not reach the server. Please check your internet and try again.';
const _kUnexpectedError =
    'An unexpected error occurred. Please try again or contact support.';
const _kEventInactive =
    'Registration is currently closed. If you received an invite, please contact support.';
const _kNotFound =
    'Username not found or registration code invalid. Please double-check both fields and try again.';
const _kCodeUsed =
    'This registration code has already been used. If this is your code, try re-entering your exact username.';
const _kValidation = 'Please fill in both your username and registration code.';
const _kGeneric = 'Registration failed. Please try again or contact support.';
const _kStaleBannerBody =
    'Your registration may be from a previous season. Blocks produced with old credentials won\'t earn points.';
const _kStaleTitle = 'Registration Expired';
const _kStaleBody =
    'Your registration is from a previous season. Blocks produced with old credentials won\'t earn points. Please re-register to participate in the current season.';
const _kStaleAction = 'Re-register';

WidgetbookComponent registrationErrorsComponent() {
  return WidgetbookComponent(
    name: 'Registration Errors',
    useCases: [
      _playground(),
      _allStates(),
      _staleBanner(),
      _staleScreen(),
    ],
  );
}

// ---------------------------------------------------------------------------
// Error scenario enum (drives the playground)
// ---------------------------------------------------------------------------

enum _ErrorScenario {
  none('None (success)', 'Success — no error'),
  apiEventInactive('403 — Registration closed', _kEventInactive),
  apiNotFound('404 — Username/code invalid', _kNotFound),
  apiCodeUsed('409 — Code already used', _kCodeUsed),
  apiValidation('422 — Validation error', _kValidation),
  apiGeneric('5xx — Server error', _kGeneric),
  keyDerivation('FFI — Key derivation failed', _kKeyDerivationFailed),
  secureStorage('Storage — Secure storage failed', _kStorageFailed),
  backendStart('Backend — Node startup failed', _kBackendStartFailed),
  timeout('Network — Timeout', _kTimeoutError),
  network('Network — Connection refused', _kNetworkError),
  unexpected('Catch-all — Unexpected error', _kUnexpectedError);

  const _ErrorScenario(this.label, this.message);
  final String label;
  final String message;
}

// ---------------------------------------------------------------------------
// Playground — trigger SnackBars for each error scenario
// ---------------------------------------------------------------------------

WidgetbookUseCase _playground() {
  return WidgetbookUseCase(
    name: 'Playground',
    builder: (context) {
      final scenario = context.knobs.object.dropdown<_ErrorScenario>(
        label: 'Error Scenario',
        options: _ErrorScenario.values,
        initialOption: _ErrorScenario.none,
        labelBuilder: (s) => s.label,
      );

      return _PlaygroundPage(scenario: scenario);
    },
  );
}

class _PlaygroundPage extends StatelessWidget {
  const _PlaygroundPage({required this.scenario});
  final _ErrorScenario scenario;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registration Error Playground',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: spacing.space8),
              Text(
                'Select an error scenario from knobs, then tap the button '
                'to see the SnackBar message the user would see.',
                style: theme.textTheme.bodySmall,
              ),
              SizedBox(height: spacing.space24),
              SizedBox(
                width: double.infinity,
                child: Button(
                  label: 'Trigger Error',
                  variant: ButtonVariant.primary,
                  size: ButtonSize.large,
                  onTap: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(scenario.message)));
                  },
                ),
              ),
              SizedBox(height: spacing.space16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.space12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: radii.borderRadiusSmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scenario.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: spacing.space4),
                    Text(
                      scenario.message,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
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
// All States — static gallery of every error message
// ---------------------------------------------------------------------------

WidgetbookUseCase _allStates() {
  return WidgetbookUseCase(
    name: 'All Error Messages',
    builder: (context) {
      final spacing = Theme.of(context).extension<AppSpacing>()!;
      final theme = Theme.of(context);

      return Scaffold(
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(spacing.space16),
            children: [
              Text('Registration Error Messages',
                  style: theme.textTheme.titleMedium),
              SizedBox(height: spacing.space16),
              for (final scenario in _ErrorScenario.values)
                if (scenario != _ErrorScenario.none) ...[
                  _ErrorCard(
                    label: scenario.label,
                    message: scenario.message,
                  ),
                  SizedBox(height: spacing.space8),
                ],
            ],
          ),
        ),
      );
    },
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.label, required this.message});
  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.space12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: radii.borderRadiusSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing.space4),
          Text(message, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
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
