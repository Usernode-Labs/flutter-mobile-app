import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/url_launcher.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';

/// Presents the current terms and records the user's decision.
///
/// Mounted two ways:
/// - `gateMode: true` — stacked over the whole app on launch when the current
///   version has never been answered. No back affordance: the user must choose,
///   though *both* choices let them into the app.
/// - `gateMode: false` — a normal pushed page from Settings, so a user can
///   accept later or withdraw a previous consent.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key, this.gateMode = false});

  /// Whether this is the launch gate rather than a pushed page.
  final bool gateMode;

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  /// Which decision is in flight, or null when idle. Also disables both buttons:
  /// consent POSTs are not retried, so a double tap would fire two of them.
  String? _submitting;

  Future<void> _submit(String status) async {
    if (_submitting != null) return;
    setState(() => _submitting = status);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    // In gate mode this screen is stacked by MaterialApp.builder, which Flutter
    // invokes *above* the Router — so there is no Navigator ancestor and
    // Navigator.of would throw. Nothing to pop there anyway: the overlay
    // unmounts itself once the gate provider re-evaluates.
    final navigator = widget.gateMode ? null : Navigator.maybeOf(context);
    try {
      await ref.read(currentTermsProvider.notifier).submitConsent(status);
      if (!mounted) return;
      // From Settings, hand the user back where they came from.
      if (navigator != null && navigator.canPop()) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(l10n.termsSubmitFailed)));
    } finally {
      // Always restore the buttons rather than trusting something else to
      // unmount us — otherwise a gate that fails to close leaves the user
      // staring at a spinner with no way forward.
      if (mounted) setState(() => _submitting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final snapshot = ref.watch(currentTermsProvider);

    final body = snapshot.when(
      data: (value) {
        final terms = value?.terms;
        if (terms == null) {
          return EmptyState(
            icon: Symbols.gavel_sharp,
            title: l10n.termsNonePublished,
          );
        }
        return _TermsBody(
          terms: terms,
          submitting: _submitting,
          onAccept: () => _submit(TermsConsentStatus.accepted),
          onRefuse: () => _submit(TermsConsentStatus.refused),
        );
      },
      loading: () => const _TermsLoading(),
      error: (_, __) => FullPageErrorState(
        message: l10n.termsUnavailable,
        onRetry: () => ref.invalidate(currentTermsProvider),
      ),
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsTitle),
        // The gate has no exit but the two decisions.
        automaticallyImplyLeading: !widget.gateMode,
      ),
      body: SafeArea(child: body),
    );

    if (!widget.gateMode) return scaffold;

    // The Scaffold is already opaque, so it hides and blocks the app beneath it.
    // canPop: false stops the Android back button from dismissing the gate — the
    // two decisions are the only way out.
    return PopScope(canPop: false, child: scaffold);
  }
}

/// Content-shaped placeholder: lines of prose, matching what loads into it.
class _TermsLoading extends StatelessWidget {
  const _TermsLoading();

  // Ragged widths so it reads as paragraphs rather than a progress bar.
  static const _lineWidths = [1.0, 0.94, 0.97, 0.62, 1.0, 0.88, 0.93, 0.45];

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final width = MediaQuery.sizeOf(context).width - spacing.space16 * 2;

    return Padding(
      padding: EdgeInsets.all(spacing.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fraction in _lineWidths) ...[
            ShimmerBlock(width: width * fraction, height: 14),
            SizedBox(height: spacing.space12),
          ],
        ],
      ),
    );
  }
}

class _TermsBody extends StatelessWidget {
  const _TermsBody({
    required this.terms,
    required this.submitting,
    required this.onAccept,
    required this.onRefuse,
  });

  final CurrentTerms terms;
  final String? submitting;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final busy = submitting != null;

    return Column(
      children: [
        Expanded(
          child: Markdown(
            data: terms.bodyMarkdown,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space16,
              vertical: spacing.space12,
            ),
            // Links inside backend-authored markdown are launched externally;
            // launchExternalUrl ignores anything it cannot resolve.
            onTapLink: (_, href, __) {
              if (href != null) launchExternalUrl(href);
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            spacing.space16,
            spacing.space8,
            spacing.space16,
            spacing.space16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (terms.termsLink != null) ...[
                Button(
                  label: l10n.termsViewFull,
                  variant: ButtonVariant.outlined,
                  leadingIcon: Icon(
                    Symbols.open_in_new_sharp,
                    size: sizing.iconSmall,
                  ),
                  onTap: () => launchExternalUrl(terms.termsLink!),
                ),
                SizedBox(height: spacing.space8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Button(
                      label: l10n.termsRefuse,
                      variant: ButtonVariant.outlined,
                      isLoading: submitting == TermsConsentStatus.refused,
                      onTap: busy ? null : onRefuse,
                    ),
                  ),
                  SizedBox(width: spacing.space12),
                  Expanded(
                    child: Button(
                      label: l10n.termsAccept,
                      variant: ButtonVariant.primary,
                      isLoading: submitting == TermsConsentStatus.accepted,
                      onTap: busy ? null : onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
