import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/widgets/sign_in_to_view_card.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';

/// Presents the current terms and lets an unaccepted user accept them.
/// An accepted response is final and can only be reviewed here.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key, this.webViewBuilder});

  /// Test seam for environments without a platform WebView implementation.
  final Widget Function(String url)? webViewBuilder;

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  bool _submitting = false;

  bool _refreshed = false;

  // currentTermsProvider is not autoDispose, so a session that already cached a
  // consent keeps it for its whole lifetime. This screen is the only way to
  // clear the allocation gate, so it must not trust that cache: a version
  // published mid-session would otherwise render "Accepted" with no button and
  // strand the user. Invalidate rather than silentRefresh — the latter keeps the
  // stale value on error, which is the exact state we're guarding against.
  //
  // Not initState: `ref` needs the ProviderScope, which isn't resolved yet
  // there. didChangeDependencies still runs before the first build, so the
  // stale value never reaches the screen.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshed) return;
    _refreshed = true;
    ref.invalidate(currentTermsProvider);
  }

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    try {
      await ref.read(currentTermsProvider.notifier).acceptCurrentTerms();
      if (!mounted) return;
      if (navigator != null && navigator.canPop()) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text(l10n.termsSubmitFailed)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The provider deliberately stops loading for unauthenticated users
    // (its watchDeps gate), which surfaces here as a null snapshot — the
    // same shape as "nothing published". Distinguish them: guests get the
    // standard sign-in gate, not a misleading empty state.
    if (ref.watch(showSignInGateProvider)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.termsTitle)),
        body: const SafeArea(child: SignInToViewCard()),
      );
    }

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
        final termsLink = terms.termsLink;
        if (termsLink == null) {
          return EmptyState(
            icon: Symbols.gavel_sharp,
            title: l10n.termsUnavailable,
          );
        }
        return _TermsBody(
          terms: terms,
          termsLink: termsLink,
          webViewBuilder: widget.webViewBuilder,
          submitting: _submitting,
          onAccept: _accept,
        );
      },
      loading: () => const _TermsLoading(),
      error: (_, __) => FullPageErrorState(
        message: l10n.termsUnavailable,
        onRetry: () => ref.invalidate(currentTermsProvider),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.termsTitle),
      ),
      body: SafeArea(child: body),
    );
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
    required this.termsLink,
    this.webViewBuilder,
    required this.submitting,
    required this.onAccept,
  });

  final CurrentTerms terms;
  final String termsLink;
  final Widget Function(String url)? webViewBuilder;
  final bool submitting;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final accepted = terms.consent?.accepted ?? false;

    return Column(
      children: [
        Expanded(
          child:
              webViewBuilder?.call(termsLink) ?? _TermsWebView(url: termsLink),
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
              if (accepted)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Symbols.check_circle_sharp),
                    SizedBox(width: spacing.space8),
                    Text(l10n.settingsTermsAccepted),
                  ],
                )
              else
                Button(
                  label: l10n.termsAccept,
                  variant: ButtonVariant.primary,
                  isLoading: submitting,
                  onTap: submitting ? null : onAccept,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsWebView extends StatefulWidget {
  const _TermsWebView({required this.url});

  final String url;

  @override
  State<_TermsWebView> createState() => _TermsWebViewState();
}

class _TermsWebViewState extends State<_TermsWebView> {
  late final WebViewController _controller;
  var _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
      ],
    );
  }
}
