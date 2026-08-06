import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart'
    show buildEnvProvider, debugModeProvider;
import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/core/providers/wallet_provider.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/widgets/node_status_icon.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart'
    show AuthSession;
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart'
    show authRepositoryProvider, authStatusProvider, identityProvider;
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart'
    show accountReconciliationStatusProvider, identityDriverProvider;
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart'
    show nodeAccountReconcilerProvider;
import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:crypto_mobile_app/features/dapps/session_bound_auth_status.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart'
    show SocialPushState;
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zkpassport/zk_challenge_reset.dart'
    show resetChallengeState;
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart'
    show zkPassportFlowControllerProvider, zkPassportSettingsProvider;
import 'package:crypto_mobile_app/src/rust/account.dart' as frb_account;
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

part 'bridge/dapp_bridge_records.dart';
part 'bridge/dapp_bridge_auth_node.dart';
part 'bridge/dapp_bridge_wallet.dart';
part 'bridge/dapp_bridge_shortcuts.dart';
part 'bridge/dapp_bridge_settings.dart';
part 'bridge/dapp_bridge_social_push.dart';
part 'bridge/dapp_bridge_dispatch.dart';

extension on WebViewController {
  /// Debug-only: exposes the webview to Safari Web Inspector (iOS 16.4+)
  /// and chrome://inspect (Android). No-op in release builds.
  void setInspectableForDebug() {
    if (!kDebugMode) return;
    final platformController = platform;
    if (platformController is WebKitWebViewController) {
      platformController.setInspectable(true);
    } else if (platformController is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
    }
  }
}

class DappWebViewScreen extends ConsumerStatefulWidget {
  final String url;
  final String name;

  /// When true, the AppBar's leading "Home" button is hidden. Set this when
  /// the screen is mounted as the root of a bottom-nav tab (not pushed on
  /// the navigator) so the leading icon doesn't pop the surrounding shell.
  /// System back / WebView back-history handling is unaffected.
  final bool embedded;

  /// Full-screen shell mode (app-as-SV-chrome): no Flutter app bar at all —
  /// the web page owns its own header. Back handling, the JS bridge, and the
  /// tx confirmation chrome are unaffected. Implies the tab-root behavior of
  /// [embedded] (no leading "Home" button, because there is no bar).
  final bool chromeless;

  /// Fired exactly once with the outcome of the first main-frame load:
  /// `true` on the first successful [onPageFinished], `false` if a
  /// main-frame resource error lands first. Used by the shell's
  /// first-launch gate ("has SV ever rendered on this install?").
  final void Function(bool ok)? onFirstLoadResult;

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
    this.embedded = false,
    this.chromeless = false,
    this.onFirstLoadResult,
  });

  @override
  ConsumerState<DappWebViewScreen> createState() => _DappWebViewScreenState();
}

/// Shared surface for the bridge mixins in `bridge/`: the webview
/// controller, the captured provider container, JS-promise resolution
/// back into the page, the identity and trust gates, and the state
/// fields the dispatch mutates (page title latch). Domain mixins are
/// `on` this class; [_DappWebViewScreenState] applies them all.
abstract class _DappWebViewScreenStateBase
    extends ConsumerState<DappWebViewScreen> {
  late final WebViewController _controller;
  late final PrivilegedBridgePolicy _privilegedBridgePolicy;
  late final SessionHandoffGate _sessionHandoffGate;
  int _progress = 0;

  /// The app-scoped Riverpod container, captured so JS-channel handlers — which
  /// the WebView can invoke after this screen is disposed — read through it
  /// instead of the widget `ref` (which throws once disposed).
  ProviderContainer? _providersContainer;
  ProviderContainer get _providers => _providersContainer!;

  // True once the embedded hub has navigated into a dapp (web `pushState`
  // history exists). Drives the tab-root bar: shell affordances at the hub
  // root (`false`), browser chrome once drilled in (`true`). Kept in sync with
  // `_controller.canGoBack()` on every navigation callback. Only meaningful in
  // embedded (tab-root) mode; non-embedded pushes always show browser chrome.
  bool _canGoBack = false;

  static const _jsChannelName = 'Usernode';

  void _dispatchPendingSocialPushEvents();

  void _admitSessionHandoff() {
    _sessionHandoffGate.admit();
    _dispatchPendingSocialPushEvents();
  }

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  bool _showUrlEditor = false;

  // Mirrors `document.title` of the page currently loaded in the WebView,
  // refreshed on every full navigation (onPageFinished), SPA pushState
  // (onUrlChange), and via the `titleChanged` JS-channel method that the
  // page can post when it mutates `document.title` outside of a real
  // navigation (e.g. SV's `App.setHeaderTitle` after `/api/apps/:slug`
  // resolves). Falls back to [widget.name] when null/empty.
  String? _pageTitle;

  // First main-frame load outcome has been reported via
  // widget.onFirstLoadResult (shell first-launch gate). Never reset.
  bool _firstLoadReported = false;

  // Set to true the first time the page posts a `titleChanged` message via
  // the JS channel. Once true, we stop trusting `_controller.getTitle()` in
  // `_refreshPageTitle` — WKWebView's cached title lags behind the page's
  // own `document.title = ...` writes by enough frames that
  // onUrlChange-triggered refreshes routinely come back with the *previous*
  // screen's title and clobber the just-arrived channel value. The page
  // promised it would tell us about every title change, so honor that.
  //
  // Reset on every full navigation (onPageStarted) so pages that don't
  // wire up the channel still get title refreshes via the legacy
  // `getTitle()` polling path.
  bool _titleFromChannel = false;

  /// Shared gate for the bridge v3 profile/settings methods: they read and
  /// mutate app-level native state, so only the trusted SV origin may call
  /// them. Rejects the JS promise and returns false for anyone else.
  Future<bool> _requireTrustedChromeOrigin(String id, String method) async {
    if (_privilegedBridgePolicy.hasActiveCapability) return true;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method is only available to the dapps home',
    );
    return false;
  }

  bool _identityScopeIsCurrent(Identity identity) =>
      mounted && identity.sameScopeAs(ref.read(identityProvider));

  Future<void> _rejectStaleIdentityScope(String id, String method) async {
    if (!mounted) return;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method was cancelled because the active identity changed',
    );
  }

  /// Extracts a required bool from `payload.args[key]`; rejects the promise
  /// and returns null when missing or mistyped.
  Future<bool?> _requireBoolArg(
      String id, Map<String, dynamic> payload, String key) async {
    final args = payload['args'];
    final value = args is Map<String, dynamic> ? args[key] : null;
    if (value is bool) return value;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: 'args.$key (bool) is required',
    );
    return null;
  }

  /// The identity whose wallet this bridge may expose, or null when there is
  /// none: reconciling/unknown (account ownership unsettled) and guest
  /// sessions (the active registry account may belong to a previously
  /// signed-in user) get nothing. When non-null, [Identity.address] is the
  /// confirmed wallet address — handlers use it instead of reading the
  /// registry's active account, so a mid-transition registry state can never
  /// leak another identity's address.
  Identity? _bridgeWalletIdentity() {
    final identity = IdentitySnapshots.current;
    if (!identity.allowsSigning) return null;
    return identity;
  }

  Future<void> _resolveJsPromise({
    required String id,
    required Object? value,
    required String? error,
  }) async {
    final js = 'window.__usernodeResolve(${jsonEncode(id)},'
        ' ${jsonEncode(value)}, ${jsonEncode(error)});';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore callback failures.
    }
  }

  /// True while the centralized bridge policy has an active trusted
  /// main-frame capability. The dispatch gate separately requires callers to
  /// present that capability, so ambient WebView URL state is never enough.
  Future<bool> _isTrustedShortcutOrigin() async {
    return _privilegedBridgePolicy.hasActiveCapability;
  }

  /// Shared deny-path for the shortcut management handlers. Returns
  /// false (after rejecting the JS promise) when the calling page isn't
  /// the dapps home.
  Future<bool> _guardTrustedShortcutOrigin(String id) async {
    if (await _isTrustedShortcutOrigin()) return true;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: 'Homescreen shortcuts can only be managed by the dapps home',
    );
    return false;
  }
}

class _DappWebViewScreenState extends _DappWebViewScreenStateBase
    with
        _BridgeTxRecords,
        _BridgeAuthNode,
        _BridgeWallet,
        _BridgeShortcuts,
        _BridgeSettings,
        _BridgeSocialPush,
        _BridgeDispatch {
  // Transaction confirmation uses Navigator.push with an opaque route instead
  // of showModalBottomSheet. A known Flutter engine bug (fixed in 3.41.0)
  // corrupts WKWebView's gesture recognizer when a translucent modal barrier
  // overlaps the platform view. An opaque route fully obscures the WebView,
  // so Flutter doesn't coordinate gestures with it during the confirmation.

  @override
  void initState() {
    super.initState();
    _sessionHandoffGate = SessionHandoffGate(
      initiallyBlocked: widget.chromeless,
    );
    _privilegedBridgePolicy = PrivilegedBridgePolicy(
      trustedOrigin: Uri.tryParse(AppConfig.dappsTabUrl),
      allowLocalDevelopment:
          kDebugMode && AppConfig.enableLocalPrivilegedBridge,
    );
    // iOS: opt this webview into App-Bound Domains (WKAppBoundDomains in
    // Info.plist). This unlocks Service Workers — SV's offline PWA mode —
    // at the cost of restricting navigation to the bound domains. All dapp
    // surfaces we host live on those domains; external links route through
    // the openExternal bridge method / system browser instead.
    final PlatformWebViewControllerCreationParams creationParams;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      creationParams = WebKitWebViewControllerCreationParams(
        limitsNavigationsToAppBoundDomains: true,
      );
    } else {
      creationParams = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(creationParams)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Pipe WebView console.* output (including the iframe-relay tracing in
      // usernode-bridge.js) into Flutter's debug logs so it shows up in
      // `flutter run` — no Safari/remote inspector required.
      ..setOnConsoleMessage((msg) {
        debugPrint('[webview ${msg.level.name}] ${msg.message}');
      })
      // Debug builds only: allow attaching Safari Web Inspector (iOS 16.4+)
      // and chrome://inspect (Android) to the dapp webview, so bridge
      // methods can be exercised from a desktop console during development.
      ..setInspectableForDebug()
      // webview_flutter has NO default UI for window.alert() — without this
      // handler every page-side alert (dapps report errors this way) is
      // silently dropped and a failing action looks like a no-op. Surface it
      // as a SnackBar rather than a dialog: a translucent modal barrier over
      // the platform view triggers the WKWebView gesture bug described above.
      ..setOnJavaScriptAlertDialog((request) async {
        debugPrint('[webview alert] ${request.message}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(request.message),
            duration: const Duration(seconds: 6),
          ),
        );
      })
      ..addJavaScriptChannel(
        _DappWebViewScreenStateBase._jsChannelName,
        onMessageReceived: _onBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.isMainFrame) {
              _privilegedBridgePolicy.beginMainFrameNavigation();
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (!mounted) return;
            // A full page load wipes any JS state, so the channel-owns-title
            // latch has to be cleared too — the new page hasn't told us
            // anything yet, and we want `_refreshPageTitle` (firing from
            // onPageFinished below) to populate `_pageTitle` from the
            // initial `document.title` for pages that don't wire up the
            // channel. SPA pushState navigations don't fire onPageStarted,
            // so this won't clear the latch mid-session in dapps like SV.
            _titleFromChannel = false;
            setState(() => _progress = 0);
            _refreshCanGoBack();
          },
          onProgress: (progress) {
            if (!mounted) return;
            if (progress != _progress) {
              setState(() => _progress = progress);
            }
          },
          onPageFinished: (url) {
            _privilegedBridgePolicy.activateMainFrame(Uri.tryParse(url));
            if (!mounted) return;
            setState(() => _progress = 100);
            _reportFirstLoadResult(true);
            _refreshPageTitle();
            _refreshCanGoBack();
            _logServiceWorkerStateForDebug();
            // Seed the freshly loaded page with the current node status so
            // SV chrome renders the pill immediately (no first-poll gap).
            _dispatchNodeStatusEvent();
            // Same for the identity phase (bridge v4 boot orchestration).
            _dispatchAuthStatusEvent();
            _dispatchPendingSocialPushEvents();
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _privilegedBridgePolicy.observeMainFrameUrl(Uri.tryParse(url));
            }
            // SPA pushState navigation — title typically changes too.
            _refreshPageTitle();
            _refreshCanGoBack();
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() => _progress = 100);
            // Sub-resource failures (an image, a beacon) don't mean the
            // page failed; only main-frame errors flunk the first-load gate.
            if (error.isForMainFrame != false) {
              _privilegedBridgePolicy.revoke();
              _reportFirstLoadResult(false);
            }
          },
        ),
      )
      ..loadRequest(parseDappUrl(widget.url));
    // Android WebView shows no OS file chooser for <input type="file">
    // unless the host app registers one (WebChromeClient.onShowFileChooser)
    // — without this, upload controls in dapps (including cross-origin
    // iframes like staging previews) silently no-op. iOS WKWebView
    // presents its own picker natively, so this is Android-only.
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setOnShowFileSelector(_showAndroidFileSelector);
    }
    // Push node pill-state transitions into the page (SV header pill).
    // Chrome-level provider only changes on real state flips (hysteresis
    // inside), so this doesn't spam the page with the 1s status poll.
    // Subscription is auto-closed when this State is disposed.
    ref.listenManual(
      topStatusChromeNodeStatusProvider,
      (_, __) => _dispatchNodeStatusEvent(),
    );
    // Push identity phase transitions into the page (bridge v4) so SV
    // chrome can render login/provisioning progress and request node
    // start once the identity settles.
    ref.listenManual(
      identityProvider,
      (previous, next) {
        if (previous?.phase == next.phase &&
            previous?.address == next.address &&
            previous?.participantId == next.participantId &&
            previous?.epoch == next.epoch) {
          return;
        }
        _dispatchAuthStatusEvent();
        // A standalone dapp surface may have been entered while the
        // identity was still reconciling — retry the node ensure once it
        // settles to ready.
        if (next.phase == IdentityPhase.ready) {
          unawaited(_ensureNodeForStandaloneDappEntry());
        }
      },
    );
    ref.listenManual(
      accountReconciliationStatusProvider,
      (previous, next) {
        if (previous == next) return;
        _dispatchAuthStatusEvent();
      },
    );
    _listenForSocialPushEvents();
    _loadTxRecords();
    _loadDappTxIds();
    unawaited(_ensureNodeForStandaloneDappEntry());
  }

  /// Presents the OS file picker for a WebView `<input type="file">` tap
  /// and returns the chosen file URIs (empty list = user cancelled).
  Future<List<String>> _showAndroidFileSelector(
      FileSelectorParams params) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: _pickerTypeForAcceptTypes(params.acceptTypes),
      );
      if (result == null) return const [];
      return result.paths
          .whereType<String>()
          .map((path) => Uri.file(path).toString())
          .toList();
    } catch (e, st) {
      debugPrint('[webview file-chooser] pick failed: $e\n$st');
      return const [];
    }
  }

  /// Maps the input's `accept` MIME types to the closest picker filter.
  /// Mixed or unknown accept lists fall back to the unfiltered picker —
  /// the page still validates what it receives, this is just UX.
  FileType _pickerTypeForAcceptTypes(List<String> acceptTypes) {
    final types = acceptTypes
        .expand((t) => t.split(','))
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();
    if (types.isEmpty) return FileType.any;
    if (types.every((t) => t.startsWith('image/'))) return FileType.image;
    if (types.every((t) => t.startsWith('video/'))) return FileType.video;
    if (types.every((t) => t.startsWith('audio/'))) return FileType.audio;
    if (types.every((t) => t.startsWith('image/') || t.startsWith('video/'))) {
      return FileType.media;
    }
    return FileType.any;
  }

  /// Reports the first main-frame load outcome exactly once (shell
  /// first-launch gate). Success and failure race; whichever navigation
  /// callback lands first wins.
  void _reportFirstLoadResult(bool ok) {
    if (_firstLoadReported) return;
    _firstLoadReported = true;
    widget.onFirstLoadResult?.call(ok);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providersContainer ??= ProviderScope.containerOf(context, listen: false);
    _controller.setBackgroundColor(
        Theme.of(context).colorScheme.surfaceContainerLowest);
  }

  @override
  void dispose() {
    _privilegedBridgePolicy.revoke();
    _disposeSocialPushEvents();
    _confirmPoller?.cancel();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  /// Debug builds only: reports whether the page can (and did) register a
  /// service worker. On iOS this verifies the App-Bound Domains opt-in took
  /// effect (without it, `navigator.serviceWorker` is undefined in
  /// WKWebView). Output lands in the piped webview console logs.
  void _logServiceWorkerStateForDebug() {
    if (!kDebugMode) return;
    _controller.runJavaScript('''
      (function () {
        if (!('serviceWorker' in navigator)) {
          console.log('[sw-check] navigator.serviceWorker unavailable');
          return;
        }
        navigator.serviceWorker.getRegistration().then(function (reg) {
          console.log('[sw-check] serviceWorker available; registration: '
            + (reg ? reg.scope : 'none'));
        }).catch(function (e) {
          console.log('[sw-check] getRegistration failed: ' + e);
        });
      })();
    ''').catchError((_) {});
  }

  Future<void> _refreshPageTitle() async {
    // The page is driving titles via the JS channel, so getTitle() is no
    // longer a reliable source — WKWebView lags behind the page's own
    // `document.title` writes by enough that an onUrlChange-triggered
    // refresh routinely returns the *previous* screen's title. Bail out
    // and trust whatever the channel set on us.
    if (_titleFromChannel) return;
    try {
      final title = await _controller.getTitle();
      if (!mounted) return;
      // Re-check the latch after the async gap; a `titleChanged` message
      // may have arrived while we were awaiting getTitle().
      if (_titleFromChannel) return;
      final normalized = title?.trim();
      if (normalized == _pageTitle) return;
      setState(() {
        _pageTitle = normalized;
      });
    } catch (_) {
      // Ignore — title is purely cosmetic, fallback is widget.name.
    }
  }

  // Refreshes [_canGoBack] from the WebView session history so the tab-root
  // bar can flip between shell affordances (hub root) and browser chrome
  // (drilled into a dapp). No-op visual cost when the value is unchanged.
  Future<void> _refreshCanGoBack() async {
    if (!widget.embedded) return;
    try {
      final canGoBack = await _controller.canGoBack();
      if (!mounted || canGoBack == _canGoBack) return;
      setState(() => _canGoBack = canGoBack);
    } catch (_) {
      // Ignore — bar mode is cosmetic; defaults to shell at the root.
    }
  }

  void _toggleUrlEditor() {
    setState(() {
      _showUrlEditor = !_showUrlEditor;
    });

    if (!_showUrlEditor) return;

    () async {
      try {
        final current = await _controller.currentUrl();
        if (!mounted) return;
        if (!_showUrlEditor) return;
        if (_urlController.text.trim().isNotEmpty) return;
        _urlController.text = current ?? '';
      } catch (_) {
        // Ignore.
      }
    }();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _urlFocusNode.requestFocus();
    });
  }

  Future<void> _loadUrlFromInput() async {
    final trimmed = _urlController.text.trim();
    if (trimmed.isEmpty) return;
    final uri = parseDappUrl(trimmed);
    await _controller.loadRequest(uri);
  }

  Future<void> _openTxDebugPanel() async {
    final userAddress = _bridgeWalletIdentity()?.address;
    final dappUri = parseDappUrl(widget.url);
    final explorerOrigin = Uri(
      scheme: dappUri.scheme,
      host: dappUri.host,
      port: dappUri.port,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => _TxDebugPanel(
          dappTxIds: _dappTxIds,
          txRecords: _txRecords,
          userAddress: userAddress,
          explorerOrigin: explorerOrigin,
          onRecordsUpdated: () {
            _saveTxRecords();
          },
        ),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The webview lives directly in the Scaffold body (NOT inside a
    // CustomScrollView/SliverFillRemaining): hosting the WebView's SurfaceView
    // platform view inside a scrollable starves it of buffers and ANRs the app
    // (BLASTBufferQueue "can't acquire next buffer").
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      // Take over the route-pop handler so the device/system back button
      // walks the WebView's session history first (pushState entries
      // from the dapp's own client-side router count as history) and
      // only pops the Flutter route once we're at the WebView root.
      // Without this the Android back button would always exit the
      // dapp, regardless of how deep the user has navigated inside it.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        // Chromeless (full-screen SV shell): the page owns its own header,
        // so no Flutter bar at all — just keep the webview out from under
        // the OS status bar.
        appBar: widget.chromeless ? null : _buildBrowserAppBar(context),
        body: ColoredBox(
          color: colors.surfaceContainerLowest,
          child: widget.chromeless
              ? SafeArea(
                  bottom: false,
                  child: WebViewWidget(controller: _controller),
                )
              : WebViewWidget(controller: _controller),
        ),
      ),
    );
  }

  IconButton _buildBrowserLeading(BuildContext context, AppSizing sizing) {
    if (widget.embedded) {
      return IconButton(
        tooltip: 'Back',
        onPressed: _handleBack,
        icon: Icon(Symbols.arrow_back_sharp, size: sizing.iconRegular),
      );
    }

    return IconButton(
      tooltip: 'Home',
      // Deep-linked entries (homescreen widget/shortcut) have nothing
      // underneath on the stack — popping the last route leaves a black
      // screen, so fall through to the dapps tab (this button lives on
      // dapp browser chrome; challenges would be a non-sequitur).
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.dapps);
        }
      },
      icon: Icon(Symbols.home_sharp, size: sizing.iconRegular),
    );
  }

  List<Widget> _buildBrowserActions(BuildContext context) {
    return [
      const NodeStatusIcon(),
      IconButton(
        tooltip: 'Transaction log',
        onPressed: _openTxDebugPanel,
        icon: const Icon(Symbols.receipt_long),
      ),
    ];
  }

  /// Drilled-in / non-embedded browser chrome: back, live page title (tap for
  /// the URL editor), loading bar, node indicator, and the transaction log.
  PreferredSizeWidget _buildBrowserAppBar(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final showLoading = _progress < 100;

    final bottomWidgets = <Widget>[
      if (showLoading)
        LinearProgressIndicator(
          minHeight: 2,
          value: _progress <= 0 ? null : _progress / 100,
        ),
      if (_showUrlEditor)
        Padding(
          padding: EdgeInsets.all(spacing.space12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                // Walks WebView session history first (covers in-page
                // pushState navigation), falling through to the route
                // pop only at WebView root — identical to the system
                // back button's behavior.
                onPressed: _handleBack,
                icon: const Icon(Symbols.arrow_back_sharp),
              ),
              SizedBox(width: spacing.space8),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _loadUrlFromInput(),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Enter URL (e.g. localhost:8000)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: spacing.space12),
              Button(
                label: 'Go',
                variant: ButtonVariant.primary,
                size: ButtonSize.small,
                onTap: _loadUrlFromInput,
              ),
              SizedBox(width: spacing.space8),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _controller.reload(),
                icon: const Icon(Symbols.refresh_sharp),
              ),
            ],
          ),
        ),
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: colors.surfaceContainerLowest,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      toolbarHeight: sizing.iconContainerXLarge,
      // Embedded nested view drills back through web history (mirrors the
      // Profile/Node pushed-page back button); non-embedded jumps to the
      // dapp list. The system back button still walks history via
      // PopScope.onPopInvokedWithResult above.
      leading: _buildBrowserLeading(context, sizing),
      title: GestureDetector(
        onTap: _toggleUrlEditor,
        behavior: HitTestBehavior.opaque,
        child: Text(
          _pageTitle?.isNotEmpty == true ? _pageTitle! : widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      titleSpacing: 0,
      actions: _buildBrowserActions(context),
      actionsPadding: EdgeInsetsDirectional.only(end: spacing.space16),
      bottom: bottomWidgets.isEmpty
          ? null
          : PreferredSize(
              preferredSize: Size.fromHeight(
                (showLoading ? 2 : 0) + (_showUrlEditor ? 62 : 0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.surfaceContainerLowest),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: bottomWidgets,
                ),
              ),
            ),
    );
  }

  // Single back-button entry point shared by the AppBar leading icon
  // and the PopScope's onPopInvokedWithResult. Walks the WebView's
  // session history first (covers in-page pushState navigation in
  // dapps like social-vibecoding: home → app → group-chat → back goes
  // to app, not out of the dapp) and only falls through to popping
  // the Flutter route once the WebView is at its root.
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}

// ---------------------------------------------------------------------------
// Transaction debug panel (opaque route — no WebView overlap)
// ---------------------------------------------------------------------------

class _TxDebugPanel extends StatefulWidget {
  final Set<String> dappTxIds;
  final Map<String, _TxRecord> txRecords;
  final String? userAddress;
  final Uri explorerOrigin;
  final VoidCallback onRecordsUpdated;

  const _TxDebugPanel({
    required this.dappTxIds,
    required this.txRecords,
    required this.userAddress,
    required this.explorerOrigin,
    required this.onRecordsUpdated,
  });

  @override
  State<_TxDebugPanel> createState() => _TxDebugPanelState();
}

class _TxDebugPanelState extends State<_TxDebugPanel> {
  bool _loading = false;
  String? _fetchError;
  int? _expandedIndex;
  late final Timer _ageTicker;

  @override
  void initState() {
    super.initState();
    _ageTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _fetchExplorerData();
  }

  @override
  void dispose() {
    _ageTicker.cancel();
    super.dispose();
  }

  List<_TxRecord> _sortedRecords() {
    final records = <_TxRecord>[];
    for (final id in widget.dappTxIds) {
      final rec = widget.txRecords[id];
      if (rec != null) records.add(rec);
    }
    records.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return records;
  }

  Future<void> _refresh() async {
    setState(() {
      _fetchError = null;
      _loading = true;
    });
    await _fetchExplorerData();
  }

  Future<void> _fetchExplorerData() async {
    final address = widget.userAddress;
    if (address == null || address.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final pending = <String, DateTime>{};
    for (final id in widget.dappTxIds) {
      final rec = widget.txRecords[id];
      if (rec == null) continue;
      if (rec.status != _TxStatus.queued) continue;
      if (rec.id.startsWith('local_')) continue;
      if (rec.confirmedAt != null) continue;
      pending[rec.id] = rec.sentAt;
    }

    if (pending.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final base = widget.explorerOrigin;
      final chainRes =
          await http.get(base.resolve('/explorer-api/active_chain'));
      if (chainRes.statusCode != 200) {
        throw Exception('Chain discovery failed (${chainRes.statusCode})');
      }
      final chainData = jsonDecode(chainRes.body) as Map<String, dynamic>;
      final chainId = chainData['chain_id'] as String?;
      if (chainId == null) throw Exception('No chain_id in response');

      final earliest = pending.values.reduce(
        (a, b) => a.isBefore(b) ? a : b,
      );
      final fromTs = earliest.millisecondsSinceEpoch - 60000;

      final txUrl = base.resolve('/explorer-api/$chainId/transactions');
      final txRes = await http.post(
        txUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': address,
          'from_timestamp': fromTs,
          'limit': 50,
        }),
      );
      if (txRes.statusCode != 200) {
        throw Exception('Transaction fetch failed (${txRes.statusCode})');
      }

      final txData = jsonDecode(txRes.body) as Map<String, dynamic>;
      final items = (txData['items'] as List<dynamic>?) ?? [];
      var found = false;
      final now = DateTime.now();

      for (final item in items) {
        final j = item as Map<String, dynamic>;
        final txId =
            (j['tx_id'] ?? j['id'] ?? j['txid'] ?? j['hash'] ?? '') as String;
        final status = j['status'] as String?;
        if (txId.isNotEmpty &&
            status == 'confirmed' &&
            pending.containsKey(txId)) {
          final rec = widget.txRecords[txId];
          if (rec != null && rec.confirmedAt == null) {
            widget.txRecords[txId] = rec.copyWith(
              confirmedAt: now,
              inclusionLatencyMs: (j['inclusion_latency_ms'] as num?)?.toInt(),
              blockHeight: (j['block_height'] as num?)?.toInt(),
              onChainTimestampMs: (j['timestamp_ms'] as num?)?.toInt(),
              onChainStatus: status,
            );
            found = true;
          }
        }
      }

      if (found) widget.onRecordsUpdated();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;
    final records = _sortedRecords();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: const Text('Transaction Log'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              Padding(
                padding: EdgeInsets.all(spacing.space16),
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            if (_fetchError != null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.space16,
                  vertical: spacing.space8,
                ),
                child: Text(
                  'Explorer fetch failed: $_fetchError',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: records.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: spacing.space16 * 6),
                          Center(
                            child: Text(
                              'No transactions yet',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: muted),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(spacing.space16),
                        itemCount: records.length,
                        itemBuilder: (ctx, index) {
                          final rec = records[index];
                          final isExpanded = _expandedIndex == index;
                          final isConfirmed = rec.status == _TxStatus.queued &&
                              rec.onChainStatus == 'confirmed';

                          final (Color badgeColor, String badgeLabel) =
                              switch (rec.status) {
                            _TxStatus.denied => (
                                theme.colorScheme.error,
                                'Denied'
                              ),
                            _TxStatus.error => (
                                theme.colorScheme.error,
                                'Error'
                              ),
                            _TxStatus.queued
                                when rec.onChainStatus == 'confirmed' =>
                              (const Color(0xFF4CAF50), 'Confirmed'),
                            _TxStatus.queued
                                when rec.onChainStatus == 'orphaned' =>
                              (theme.colorScheme.error, 'Orphaned'),
                            _TxStatus.queued => (
                                const Color(0xFFFFA726),
                                'Pending'
                              ),
                          };

                          String memoType = '';
                          try {
                            final parsed =
                                jsonDecode(rec.memo) as Map<String, dynamic>;
                            memoType = parsed['type'] as String? ?? '';
                          } catch (_) {}

                          final age = DateTime.now().difference(rec.sentAt);
                          final ageStr = age.inMinutes < 1
                              ? 'sent ${age.inSeconds}s ago'
                              : age.inHours < 1
                                  ? 'sent ${age.inMinutes}m ago'
                                  : age.inDays < 1
                                      ? 'sent ${age.inHours}h ago'
                                      : 'sent ${age.inDays}d ago';

                          // Header pill: fastest "total" signal we have for
                          // a confirmed tx (best of explorer/dapp, then
                          // explorer-only inclusion latency as a final
                          // fallback for the explorer-comes-first case
                          // before its `confirmedAt` lands).
                          String? confirmTimeStr;
                          int? confirmTotalSecs;
                          if (isConfirmed) {
                            final totalMs =
                                rec.bestTotalMs ?? rec.inclusionLatencyMs;
                            if (totalMs != null && totalMs >= 0) {
                              final secs = totalMs ~/ 1000;
                              confirmTotalSecs = secs;
                              confirmTimeStr = secs < 60
                                  ? '${secs}s'
                                  : '${secs ~/ 60}m ${secs % 60}s';
                            }
                          }

                          final txHash =
                              rec.id.startsWith('local_') ? null : rec.id;

                          return Padding(
                            padding: EdgeInsets.only(bottom: spacing.space8),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? null : index;
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.all(spacing.space12),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withAlpha(100),
                                  borderRadius: radii.borderRadiusMedium,
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant
                                        .withAlpha(80),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withAlpha(30),
                                            borderRadius:
                                                radii.borderRadiusXSmall,
                                          ),
                                          child: Text(
                                            badgeLabel,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: badgeColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (confirmTimeStr != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(right: 6),
                                            child: Text(
                                              '\u{23F1} $confirmTimeStr',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                color: _latencyColor(
                                                    confirmTotalSecs ?? 0),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          ageStr,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: muted),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: spacing.space8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'To: ${_truncate(rec.to, 20)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              fontFamily: kMonoFontFamily,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Amt: ${rec.amount}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    if (memoType.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          'type: $memoType',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: muted),
                                        ),
                                      ),
                                    if (txHash != null && txHash.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          'tx: ${_truncate(txHash, 24)}',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            fontFamily: kMonoFontFamily,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    if (rec.status == _TxStatus.error &&
                                        rec.errorMessage != null)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: spacing.space4),
                                        child: Text(
                                          rec.errorMessage!,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    if (isExpanded) ...[
                                      const Divider(height: 16),
                                      if ((isConfirmed &&
                                              rec.inclusionLatencyMs != null) ||
                                          rec.dappObservedAtMs != null)
                                        _buildLatencyRow(
                                          theme: theme,
                                          muted: muted,
                                          rec: rec,
                                        ),
                                      _detailRow(theme, muted, 'From', rec.from,
                                          mono: true),
                                      _detailRow(theme, muted, 'To', rec.to,
                                          mono: true),
                                      _detailRow(theme, muted, 'Amount',
                                          rec.amount.toString()),
                                      if (txHash != null && txHash.isNotEmpty)
                                        _detailRow(
                                            theme, muted, 'Tx Hash', txHash,
                                            mono: true),
                                      if (rec.blockHeight != null)
                                        _detailRow(theme, muted, 'Block',
                                            rec.blockHeight.toString()),
                                      _detailRow(theme, muted, 'Memo',
                                          _formatMemo(rec.memo)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatencyRow({
    required ThemeData theme,
    required Color muted,
    required _TxRecord rec,
  }) {
    // Per-channel totals + last-mile come from the helpers on _TxRecord —
    // see the doc-comment there. "Total" is the best-of, so the user sees
    // the fastest path; the per-channel last-mile columns stay split so
    // it's clear which path delivered first.
    final bestTotalMs = rec.bestTotalMs;
    final explorerLastMileMs = rec.explorerLastMileMs;
    final dappLastMileMs = rec.dappLastMileMs;
    final inclusionMs = rec.inclusionLatencyMs;

    String fmt(int? ms) {
      if (ms == null) return '--';
      final s = ms ~/ 1000;
      return s < 60 ? '${s}s' : '${s ~/ 60}m ${s % 60}s';
    }

    Color? totalColor;
    if (bestTotalMs != null) {
      totalColor = _latencyColor(bestTotalMs ~/ 1000);
    }

    Widget col(String label, String value, {Color? color}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: color != null ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          col(
            'Total',
            bestTotalMs != null ? '\u{23F1} ${fmt(bestTotalMs)}' : '--',
            color: totalColor,
          ),
          col('Inclusion', fmt(inclusionMs)),
          col('Last mile (explorer)', fmt(explorerLastMileMs)),
          col('Last mile (dapp)', fmt(dappLastMileMs)),
        ],
      ),
    );
  }

  static Widget _detailRow(
    ThemeData theme,
    Color muted,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: mono ? kMonoFontFamily : null,
            ),
          ),
        ],
      ),
    );
  }

  static Color _latencyColor(int totalSecs) {
    if (totalSecs < 20) return const Color(0xFF4CAF50);
    if (totalSecs <= 40) return const Color(0xFFFFA726);
    return const Color(0xFFF44336);
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    final half = (maxLen - 1) ~/ 2;
    return '${s.substring(0, half)}\u{2026}${s.substring(s.length - half)}';
  }

  static String _formatMemo(String memo) {
    try {
      final parsed = jsonDecode(memo);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (_) {
      return memo;
    }
  }
}
