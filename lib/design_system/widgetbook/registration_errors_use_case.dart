import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';

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
  none('None (success)'),
  apiEventInactive('403 — Registration closed'),
  apiNotFound('404 — Username/code invalid'),
  apiCodeUsed('409 — Code already used'),
  apiValidation('422 — Validation error'),
  apiGeneric('5xx — Server error'),
  keyDerivation('FFI — Key derivation failed'),
  secureStorage('Storage — Secure storage failed'),
  backendStart('Backend — Node startup failed'),
  timeout('Network — Timeout'),
  network('Network — Connection refused'),
  unexpected('Catch-all — Unexpected error');

  const _ErrorScenario(this.label);
  final String label;
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
    final l10n = AppLocalizations.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final theme = Theme.of(context);

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
                  onTap: () => _showError(context, scenario, l10n),
                ),
              ),
              SizedBox(height: spacing.space16),
              // Show the raw message text below for easy reading
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(spacing.space12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: Theme.of(context)
                      .extension<AppRadii>()!
                      .borderRadiusSmall,
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
                      _messageForScenario(scenario, l10n),
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

  void _showError(
      BuildContext context, _ErrorScenario scenario, AppLocalizations l10n) {
    final message = _messageForScenario(scenario, l10n);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _messageForScenario(_ErrorScenario scenario, AppLocalizations l10n) {
  return switch (scenario) {
    _ErrorScenario.none => 'Success — no error',
    _ErrorScenario.apiEventInactive =>
      'Registration is currently closed. If you received an invite, please contact support.',
    _ErrorScenario.apiNotFound =>
      'Username not found or registration code invalid. Please double-check both fields and try again.',
    _ErrorScenario.apiCodeUsed =>
      'This registration code has already been used. If this is your code, try re-entering your exact username.',
    _ErrorScenario.apiValidation =>
      'Please fill in both your username and registration code.',
    _ErrorScenario.apiGeneric =>
      'Registration failed. Please try again or contact support.',
    _ErrorScenario.keyDerivation => l10n.importApiAccountKeyDerivationFailed,
    _ErrorScenario.secureStorage => l10n.importApiAccountStorageFailed,
    _ErrorScenario.backendStart => l10n.importApiAccountBackendStartFailed,
    _ErrorScenario.timeout => l10n.registrationTimeoutError,
    _ErrorScenario.network => l10n.registrationNetworkError,
    _ErrorScenario.unexpected => l10n.registrationUnexpectedError,
  };
}

// ---------------------------------------------------------------------------
// All States — static gallery of every error message
// ---------------------------------------------------------------------------

WidgetbookUseCase _allStates() {
  return WidgetbookUseCase(
    name: 'All Error Messages',
    builder: (context) {
      final l10n = AppLocalizations.of(context);
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
                    message: _messageForScenario(scenario, l10n),
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = Theme.of(context).extension<AppSpacing>()!;

    return Scaffold(
      body: Column(
        children: [
          // Banner area
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
                l10n.registrationStaleBannerBody,
                style: theme.textTheme.bodySmall,
              ),
              actions: [
                TextButton(
                  onPressed: () {},
                  child: Text(l10n.registrationStaleBannerDismiss),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(l10n.registrationStaleAction),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          // Placeholder content representing the home screen
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
      final l10n = AppLocalizations.of(context);
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
                  l10n.registrationStaleTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.space16),
                Text(
                  l10n.registrationStaleBody,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                Button(
                  label: l10n.registrationStaleAction,
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
