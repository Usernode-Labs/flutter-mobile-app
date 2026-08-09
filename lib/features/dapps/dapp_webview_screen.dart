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
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart'
    show AuthSession, Participant;
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart'
    show authStatusProvider, identityProvider;
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart'
    show nodeAccountReconcilerProvider;
import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';
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

/// Full-screen chromeless webview hosting the SV platform (app-as-SV-chrome):
/// the web page owns its own header, native code contributes only the JS
/// bridge, system-back handling, and the tx confirmation chrome. The legacy
/// standalone dapp browser (native app bar, URL editor, receipts sheet) was
/// removed once every entry point — including widget/shortcut deep links —
/// routed into the SV shell.
class DappWebViewScreen extends ConsumerStatefulWidget {
  final String url;

  /// Display name used in native confirmation chrome (e.g. the signMessage
  /// sheet subtitle).
  final String name;

  /// Fired exactly once with the outcome of the first main-frame load:
  /// `true` on the first successful [onPageFinished], `false` if a
  /// main-frame resource error lands first. Used by the shell's
  /// first-launch gate ("has SV ever rendered on this install?").
  final void Function(bool ok)? onFirstLoadResult;

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
    this.onFirstLoadResult,
  });

  @override
  ConsumerState<DappWebViewScreen> createState() => _DappWebViewScreenState();
}

/// Shared surface for the bridge mixins in `bridge/`: the webview
/// controller, the captured provider container, JS-promise resolution
/// back into the page, and the identity and trust gates. Domain mixins are
/// `on` this class; [_DappWebViewScreenState] applies them all.
abstract class _DappWebViewScreenStateBase
    extends ConsumerState<DappWebViewScreen> {
  late final WebViewController _controller;

  /// The app-scoped Riverpod container, captured so JS-channel handlers — which
  /// the WebView can invoke after this screen is disposed — read through it
  /// instead of the widget `ref` (which throws once disposed).
  ProviderContainer? _providersContainer;
  ProviderContainer get _providers => _providersContainer!;

  static const _jsChannelName = 'Usernode';

  // First main-frame load outcome has been reported via
  // widget.onFirstLoadResult (shell first-launch gate). Never reset.
  bool _firstLoadReported = false;

  /// Shared gate for the bridge v3 profile/settings methods: they read and
  /// mutate app-level native state, so only the trusted SV origin may call
  /// them. Rejects the JS promise and returns false for anyone else.
  Future<bool> _requireTrustedChromeOrigin(String id, String method) async {
    if (await _isTrustedShortcutOrigin()) return true;
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

  /// True when the top frame currently shows the configured dapps-tab
  /// home (social vibecoding) — the only page trusted to manage
  /// homescreen shortcuts. Sub-apps live on their own subdomains (or are
  /// iframes whose relayed calls the SV bridge refuses to forward), so
  /// an exact origin match on the current URL is the boundary. Local-dev
  /// hosts pass so `--local-dev` SV builds stay testable.
  Future<bool> _isTrustedShortcutOrigin() async {
    final raw = await _controller.currentUrl();
    final current = raw == null ? null : Uri.tryParse(raw);
    if (current == null || current.host.isEmpty) return false;
    if (_isLocalDevHost(current.host)) return true;
    final trusted = Uri.tryParse(AppConfig.dappsTabUrl);
    if (trusted == null || trusted.host.isEmpty) return false;
    return current.scheme == trusted.scheme &&
        current.host == trusted.host &&
        current.port == trusted.port;
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
        _BridgeDispatch {
  // Transaction confirmation uses Navigator.push with an opaque route instead
  // of showModalBottomSheet. A known Flutter engine bug (fixed in 3.41.0)
  // corrupts WKWebView's gesture recognizer when a translucent modal barrier
  // overlaps the platform view. An opaque route fully obscures the WebView,
  // so Flutter doesn't coordinate gestures with it during the confirmation.

  @override
  void initState() {
    super.initState();
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
          onPageFinished: (_) {
            if (!mounted) return;
            _reportFirstLoadResult(true);
            _logServiceWorkerStateForDebug();
            // Seed the freshly loaded page with the current node status so
            // SV chrome renders the pill immediately (no first-poll gap).
            _dispatchNodeStatusEvent();
            // Same for the identity phase (bridge v4 boot orchestration).
            _dispatchAuthStatusEvent();
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            // Sub-resource failures (an image, a beacon) don't mean the
            // page failed; only main-frame errors flunk the first-load gate.
            if (error.isForMainFrame != false) {
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
            previous?.address == next.address) {
          return;
        }
        _dispatchAuthStatusEvent();
      },
    );
    _loadTxRecords();
    _loadDappTxIds();
  }

  /// Reacts to a changed [DappWebViewScreen.url] on a *live* webview. Most
  /// callers key this screen by URL, so a URL change recreates the state and
  /// never lands here — the exception is the SV shell, which keeps a stable
  /// key so a widget/shortcut deep link arriving while the app is warm
  /// (e.g. `/home?sv=app/<slug>`) can navigate the running SPA instead of
  /// cold-rebooting it.
  ///
  /// A fragment-only change is handed to the page as a `location.hash`
  /// assignment — the SPA's hashchange router takes it from there with its
  /// own screen transition. Anything else is a real navigation.
  @override
  void didUpdateWidget(covariant DappWebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    final next = parseDappUrl(widget.url);
    final prev = parseDappUrl(oldWidget.url);
    final sameDocument =
        next.replace(fragment: '') == prev.replace(fragment: '');
    if (sameDocument) {
      _controller
          .runJavaScript('window.location.hash = ${jsonEncode(next.fragment)};')
          .catchError((_) {});
    } else {
      _controller.loadRequest(next);
    }
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
    _confirmPoller?.cancel();
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
        // The page owns its own header, so no Flutter bar at all — just
        // keep the webview out from under the OS status bar.
        body: ColoredBox(
          color: colors.surfaceContainerLowest,
          child: SafeArea(
            bottom: false,
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ),
    );
  }

  // Back-button entry point for the PopScope's onPopInvokedWithResult.
  // Walks the WebView's session history first (covers in-page pushState
  // navigation in dapps like social-vibecoding: home → app → group-chat →
  // back goes to app, not out of the dapp) and only falls through to
  // popping the Flutter route once the WebView is at its root.
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}
