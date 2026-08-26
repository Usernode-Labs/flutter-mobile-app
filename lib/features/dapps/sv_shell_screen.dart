import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';

/// Full-screen SV shell (app-as-SV-chrome migration, flag `shell.sv`).
///
/// Renders the Social Vibecoding webapp full-bleed as the home route — no
/// bottom nav, no native top bar; SV's own header carries node status,
/// wallet, and challenges via the v2 bridge. The native tx confirm sheet
/// remains the sole chrome exception.
///
/// First-launch gate: until one SV load has ever succeeded on this install
/// (after which the service worker owns offline), a native connecting
/// screen covers the webview. Later launches enter the shell immediately.
class SvShellScreen extends ConsumerStatefulWidget {
  const SvShellScreen({super.key, this.initialHash, this.navigationRequest});

  /// Optional Social hash route to land on.
  /// — used by the deep-link remap of the retired native tabs.
  final String? initialHash;

  /// Changes for each external shortcut launch, including repeat launches of
  /// the same target, so the live webview can re-assert the requested route.
  final String? navigationRequest;

  static const _gatePrefsKey = 'sv_shell_first_load_ok';

  @override
  ConsumerState<SvShellScreen> createState() => _SvShellScreenState();
}

class _SvShellScreenState extends ConsumerState<SvShellScreen> {
  /// null while SharedPreferences loads; then whether SV has ever
  /// successfully rendered on this install.
  bool? _gatePassed;

  /// Outcome of the current attempt's first main-frame load:
  /// null = pending, false = failed (show retry). Success flips
  /// [_gatePassed] directly.
  bool? _loadOk;

  /// Bumped on retry so the webview subtree is rebuilt from scratch.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _readGate();
  }

  Future<void> _readGate() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gatePassed = prefs.getBool(SvShellScreen._gatePrefsKey) ?? false;
    });
  }

  Future<void> _onFirstLoadResult(bool ok) async {
    if (!mounted) return;
    if (ok) {
      setState(() {
        _loadOk = true;
        _gatePassed = true;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(SvShellScreen._gatePrefsKey, true);
    } else {
      setState(() => _loadOk = false);
    }
  }

  void _retry() {
    setState(() {
      _attempt++;
      _loadOk = null;
    });
  }

  /// Cold-boots the shell after a voluntary sign-out has SETTLED. Reuses the
  /// retry counter — the webview is keyed by it — so the document is rebuilt
  /// from scratch rather than soft-navigated: only a fresh load picks up the
  /// cleared web session and renders the platform's login page.
  ///
  /// Driven by [DappWebViewScreen.onSessionEnded], which the shared WebView
  /// owner fires off the settled sign-out signal. It deliberately does NOT
  /// watch `authenticated -> anything else`: sign-out publishes
  /// `transitioning` synchronously before its first await, and a replacement
  /// document created on that edge would race the cookie/storage deletion
  /// that makes the next load render a login page — and would also fire for
  /// terminal boundaries, which have no successor to build.
  void _reloadForSessionEnd() {
    if (!mounted) return;
    setState(() {
      _attempt++;
      _loadOk = null;
    });
  }

  String get _shellUrl {
    final base = AppConfig.dappsTabUrl.trim();
    final hash = widget.initialHash;
    if (hash == null || hash.isEmpty) return base;
    return '$base#$hash';
  }

  @override
  Widget build(BuildContext context) {
    final gatePassed = _gatePassed;
    if (gatePassed == null) {
      // Prefs still loading (a frame or two) — plain connecting screen,
      // no webview yet.
      return _buildGateScreen(context, failed: false);
    }

    // Keyed by attempt only — NOT by URL. A widget/shortcut deep link
    // arriving while the shell is alive updates `initialHash` (new
    // `?sv=` param on /home), and the webview handles that in
    // didUpdateWidget as a soft `location.hash` navigation on the running
    // SPA. Keying by URL here would tear the shell down and cold-boot SV
    // for every widget tap instead.
    final webview = DappWebViewScreen(
      key: ValueKey('sv-shell:$_attempt'),
      url: _shellUrl,
      name: 'Usernode',
      navigationRequest: widget.navigationRequest,
      onSessionEnded: _reloadForSessionEnd,
      onFirstLoadResult: gatePassed ? null : _onFirstLoadResult,
    );

    final children = <Widget>[
      webview,
      // First launch ever: cover the webview with the native gate until the
      // page proves it can render (then the SW owns offline forever after).
      if (!gatePassed) _buildGateScreen(context, failed: _loadOk == false),
      if (kDebugMode) _buildDebugEscapeHatch(context),
    ];

    return Stack(children: children);
  }

  /// Native connecting / offline screen shown over the webview while the
  /// first-ever SV load is in flight (or has failed).
  Widget _buildGateScreen(BuildContext context, {required bool failed}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(spacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!failed) ...[
                  const CircularProgressIndicator(),
                  SizedBox(height: spacing.space24),
                  Text(
                    l10n.svShellConnectingTitle,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    l10n.svShellOfflineMessage,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.space24),
                  Button(
                    label: l10n.retry,
                    variant: ButtonVariant.primary,
                    onTap: _retry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dev-build escape hatch to the native diagnostics screen (the production
  /// path is SV's settings calling `openNativeScreen('diagnostics')`):
  /// long-press the invisible hotspot in the bottom-left corner.
  Widget _buildDebugEscapeHatch(BuildContext context) {
    return Positioned(
      left: 0,
      bottom: 0,
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () => context.push(AppRoutes.diagnostics),
      ),
    );
  }
}
