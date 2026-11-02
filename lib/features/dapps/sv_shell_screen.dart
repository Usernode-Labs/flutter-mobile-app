import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/homeroom_link_redirect.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/sv_shell_gate.dart';
import 'package:crypto_mobile_app/core/services/native_connectivity.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';

/// Full-screen SV shell (app-as-SV-chrome migration, flag `shell.sv`).
///
/// Renders the Social Vibecoding webapp full-bleed as the home route — no
/// bottom nav, no native top bar; SV's own header carries node status,
/// wallet, and challenges via the v2 bridge. The native tx confirm sheet
/// remains the sole chrome exception.
///
/// Launch cover: the WebView is created on this screen's first frame, under
/// a [LaunchCover] that continues the native launch screen, until the page
/// says its first screen has painted (`shellPainted` on the bridge) or
/// [coverCap] passes. Then the cover fades out over [coverFade]. The page's
/// in-between stages (a blank document, a skeleton, a header laid out under
/// the status bar and then moved) happen under it. It goes up once per
/// screen, so a warm resume, where the WebView already exists, never shows
/// it.
///
/// First-launch gate: until one SV load has ever succeeded on this install
/// (after which the service worker owns offline), the cover also stays up
/// until that load succeeds, with no cap, and offers a retry if it fails or
/// has neither succeeded nor failed within [firstLoadLimit]. The load is not
/// stopped at that limit: if it succeeds later, the message goes and the
/// launch carries on as if it had been on time. While the message shows, the
/// phone coming back online retries by itself.
/// Then it waits for the paint as usual, with [coverCap] counted from the
/// load.
/// Later launches skip the gate: [SvShellGateStorage] is read before the
/// first frame.
class SvShellScreen extends ConsumerStatefulWidget {
  const SvShellScreen({
    super.key,
    this.initialHash,
    this.initialWebUrl,
    this.navigationRequest,
    required NativeSessionBridgeIngress nativeSessionBridge,
    required SessionFeatureAccessView sessionAccess,
  })  : _nativeSessionBridge = nativeSessionBridge,
        _sessionAccess = sessionAccess;

  /// Optional Social hash route to land on.
  /// — used by the deep-link remap of the retired native tabs.
  final String? initialHash;

  /// An incoming website link, validated again before it reaches the WebView.
  /// Paths and queries stay intact, including sign-in and invitation links.
  final String? initialWebUrl;

  /// Changes for each external link or shortcut, including repeat launches of
  /// the same target, so the live webview can re-assert the requested route.
  final String? navigationRequest;

  final NativeSessionBridgeIngress _nativeSessionBridge;
  final SessionFeatureAccessView _sessionAccess;

  /// The longest the cover waits for `shellPainted` once the page could be
  /// shown: from the WebView's creation on a launch past the gate, and from
  /// the first successful load on the first launch ever (which can take far
  /// longer than this, and would otherwise lift the cover on a page that has
  /// loaded but not yet painted). A build of the page that never sends it,
  /// or a page that is slow to paint, gets the cover lifted anyway.
  static const coverCap = Duration(seconds: 3);

  /// How long the first launch ever waits for its first load to succeed or
  /// fail before it says it can't reach Homeroom. A network that looks
  /// connected but passes no packets does neither for a minute or more, and
  /// "Connecting to Homeroom…" for that long reads as stuck.
  static const firstLoadLimit = Duration(seconds: 15);

  /// How long the cover takes to fade into the page.
  static const coverFade = Duration(milliseconds: 150);

  @visibleForTesting
  static const coverKey = ValueKey('sv-shell-launch-cover');

  @override
  ConsumerState<SvShellScreen> createState() => _SvShellScreenState();
}

enum _Cover { up, lifting, gone }

class _SvShellScreenState extends ConsumerState<SvShellScreen> {
  /// Whether SV has ever successfully rendered on this install. Read before
  /// the first frame, so it is never unknown here.
  late bool _gatePassed;

  /// Outcome of the current attempt's first main-frame load:
  /// null = pending, false = failed (show retry). Success flips
  /// [_gatePassed] directly.
  bool? _loadOk;

  /// [SvShellScreen.firstLoadLimit] has passed with the current attempt's
  /// first load still pending. Shows the retry, but the load goes on, and
  /// its success still passes the gate.
  bool _firstLoadOverdue = false;
  Timer? _firstLoadTimer;

  /// Watches the phone's connectivity until the gate passes, so the phone
  /// coming back online can retry a first launch that could not load.
  StreamSubscription<List<ConnectivityResult>>? _connectivity;

  /// Whether the phone was last seen online; null until it has been read.
  bool? _online;

  /// Bumped on retry so the webview subtree is rebuilt from scratch.
  int _attempt = 0;

  _Cover _cover = _Cover.up;

  /// The page has said its first screen is painted.
  bool _painted = false;

  /// [SvShellScreen.coverCap] has passed since the page could be shown.
  bool _capPassed = false;
  Timer? _capTimer;

  @override
  void initState() {
    super.initState();
    _gatePassed = SvShellGateStorage.passed;
    if (_gatePassed) {
      _startCap();
    } else {
      _startFirstLoadLimit();
      _watchConnectivity();
    }
  }

  void _startCap() {
    _capTimer?.cancel();
    _capTimer = Timer(SvShellScreen.coverCap, () {
      _capPassed = true;
      _liftCoverIfReady();
    });
  }

  void _startFirstLoadLimit() {
    _firstLoadTimer?.cancel();
    _firstLoadTimer = Timer(SvShellScreen.firstLoadLimit, () {
      if (!mounted || _gatePassed || _loadOk != null) return;
      setState(() => _firstLoadOverdue = true);
    });
  }

  void _watchConnectivity() {
    final source = ref.read(nativeConnectivityProvider);
    _connectivity = source.changes.listen(
      _onConnectivityChanged,
      onError: (Object _) {},
    );
    unawaited(source.check().then((results) {
      // A change that has already arrived is newer than this reading.
      _online ??= ConnectivitySnapshot.of(results).online;
    }, onError: (Object _) {}));
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = ConnectivitySnapshot.of(results).online;
    final cameBack = _online == false && online;
    _online = online;
    if (cameBack && mounted && _showsOfflineMessage) _retry();
  }

  void _stopWatchingConnectivity() {
    unawaited(_connectivity?.cancel());
    _connectivity = null;
  }

  @override
  void dispose() {
    _capTimer?.cancel();
    _firstLoadTimer?.cancel();
    _stopWatchingConnectivity();
    super.dispose();
  }

  /// The first launch ever could not load, or has not loaded within
  /// [SvShellScreen.firstLoadLimit].
  bool get _showsOfflineMessage =>
      !_gatePassed && (_loadOk == false || _firstLoadOverdue);

  /// Starts the fade once the page can be shown: it has loaded at least once
  /// on this install, and it has painted or the cap has passed.
  void _liftCoverIfReady() {
    if (!mounted || _cover != _Cover.up) return;
    if (!_gatePassed || !(_painted || _capPassed)) return;
    setState(() => _cover = _Cover.lifting);
  }

  /// `shellPainted` from the page. Idempotent: a repeat, or a later
  /// document's, finds the cover already lifting or gone.
  void _onShellPainted() {
    if (_painted) return;
    _painted = true;
    _liftCoverIfReady();
  }

  /// The current attempt's first load, however late. A failure after
  /// [SvShellScreen.firstLoadLimit] leaves the message that is already up.
  Future<void> _onFirstLoadResult(bool ok) async {
    if (!mounted) return;
    _firstLoadTimer?.cancel();
    if (ok) {
      _stopWatchingConnectivity();
      setState(() {
        _loadOk = true;
        _gatePassed = true;
        _firstLoadOverdue = false;
      });
      if (_painted) {
        _liftCoverIfReady();
      } else {
        _startCap();
      }
      await SvShellGateStorage.markPassed();
    } else {
      setState(() => _loadOk = false);
    }
  }

  void _retry() {
    setState(() {
      _attempt++;
      _loadOk = null;
      _firstLoadOverdue = false;
    });
    _startFirstLoadLimit();
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
      _firstLoadOverdue = false;
    });
    if (!_gatePassed) _startFirstLoadLimit();
  }

  String get _shellUrl {
    final incoming = Uri.tryParse(widget.initialWebUrl ?? '');
    final webLink = incoming == null ? null : homeroomWebLink(incoming);
    if (webLink != null) return webLink.toString();
    final base = AppConfig.platformBaseUrl.trim();
    final hash = widget.initialHash;
    if (hash == null || hash.isEmpty) return base;
    return '$base#$hash';
  }

  @override
  Widget build(BuildContext context) {
    // Keyed by attempt only — NOT by URL. A widget/shortcut deep link
    // or website link updates its destination on the running WebView.
    // didUpdateWidget navigates fragments within the SPA and loads a new
    // document when its path/query changes. Keying by URL here would tear
    // the shell down for every link or widget tap instead.
    final webview = DappWebViewScreen(
      key: ValueKey('sv-shell:$_attempt'),
      url: _shellUrl,
      name: 'Homeroom',
      navigationRequest: widget.navigationRequest,
      onSessionEnded: _reloadForSessionEnd,
      onFirstLoadResult: _gatePassed ? null : _onFirstLoadResult,
      onShellPainted: _onShellPainted,
      nativeSessionBridge: widget._nativeSessionBridge,
      sessionAccess: widget._sessionAccess,
    );

    final children = <Widget>[
      webview,
      if (_cover != _Cover.gone) _buildCover(context),
      if (kDebugMode) _buildDebugEscapeHatch(context),
    ];

    return Stack(fit: StackFit.expand, children: children);
  }

  /// The launch cover over the WebView. Stops taking taps the moment it
  /// starts to fade, so the page is usable while it goes.
  Widget _buildCover(BuildContext context) {
    final lifting = _cover == _Cover.lifting;
    return IgnorePointer(
      key: SvShellScreen.coverKey,
      ignoring: lifting,
      child: AnimatedOpacity(
        opacity: lifting ? 0 : 1,
        duration: SvShellScreen.coverFade,
        onEnd: () {
          if (mounted && _cover == _Cover.lifting) {
            setState(() => _cover = _Cover.gone);
          }
        },
        child: LaunchCover(
          message: _showsOfflineMessage ? _buildOfflineMessage(context) : null,
        ),
      ),
    );
  }

  /// Under the mark when the first-ever SV load has failed or is overdue.
  Widget _buildOfflineMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.svShellOfflineMessage,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.space16),
        Button(
          label: l10n.retry,
          variant: ButtonVariant.primary,
          onTap: _retry,
        ),
      ],
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
