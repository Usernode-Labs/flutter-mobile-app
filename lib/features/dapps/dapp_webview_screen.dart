import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart'
    show buildEnvProvider, debugModeProvider;
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';
import 'package:crypto_mobile_app/features/dapps/bridge_admission_coordinator.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';
import 'package:crypto_mobile_app/features/dapps/native_screen_capture.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:crypto_mobile_app/features/dapps/submit_transaction_contract.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart'
    show SocialPushState;
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/zk_challenge_reset.dart'
    show resetChallengeState;
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart'
    show zkPassportFlowControllerProvider;
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

part 'bridge/dapp_bridge_auth_node.dart';
part 'bridge/dapp_bridge_wallet.dart';
part 'bridge/dapp_bridge_shortcuts.dart';
part 'bridge/dapp_bridge_settings.dart';
part 'bridge/dapp_bridge_social_push.dart';
part 'bridge/dapp_bridge_capture.dart';
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

/// Full-screen chromeless webview hosting the SV platform (app-as-SV-chrome),
/// plus the compatibility fallback for pinned URLs that cannot be remapped
/// into SV's fragment router. Native code contributes the JS bridge,
/// system-back handling, and transaction-confirmation chrome.
class DappWebViewScreen extends ConsumerStatefulWidget {
  final String url;

  /// Display name used in native confirmation chrome (e.g. the signMessage
  /// sheet subtitle).
  final String name;

  /// Opaque token identifying an explicit navigation request. It lets a warm
  /// shell distinguish a repeat shortcut tap from an unrelated rebuild with
  /// unchanged widget properties.
  final Object? navigationRequest;

  /// Whether iOS restricts this webview to WKAppBoundDomains. The SV shell
  /// needs this for service workers; compatibility fallback pins must disable
  /// it so their exact non-SV URL can load.
  final bool appBoundDomainsOnly;

  /// Restores the compatibility browser contract for pins that cannot be
  /// folded into the SV shell: visible home chrome, an admitted ordinary
  /// dapp session, and standalone node lifecycle handling.
  final bool standalone;

  /// Invoked when a voluntary sign-out has fully settled, for owners that can
  /// replace this screen with a colder successor than an in-place document
  /// load (the SV shell rebuilds the whole webview subtree). When null, this
  /// screen replaces its own document — the session-end replacement lives with
  /// the WebView owner so no trusted realm can be left rendering an
  /// authenticated page.
  final VoidCallback? onSessionEnded;

  /// Fired exactly once with the outcome of the first main-frame load:
  /// `true` on the first successful [onPageFinished], `false` if a
  /// main-frame resource error lands first. Used by the shell's
  /// first-launch gate ("has SV ever rendered on this install?").
  final void Function(bool ok)? onFirstLoadResult;

  /// Private composition-root ingress. It exposes no native/root authority.
  final NativeSessionBridgeIngress _nativeSessionBridge;

  /// Immutable identity plus the exact session's one-shot operation runner.
  /// This view has no lifecycle mutation or publication authority.
  final SessionFeatureAccessView _sessionAccess;

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
    this.navigationRequest,
    this.appBoundDomainsOnly = true,
    this.standalone = false,
    this.onSessionEnded,
    this.onFirstLoadResult,
    required NativeSessionBridgeIngress nativeSessionBridge,
    required SessionFeatureAccessView sessionAccess,
  })  : _nativeSessionBridge = nativeSessionBridge,
        _sessionAccess = sessionAccess;

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
  late final PrivilegedBridgePolicy _privilegedBridgePolicy;
  late final BridgeAdmissionCoordinator _bridgeAdmissionCoordinator;
  PrivilegedBridgeLease? _readyMainFrameLease;

  /// The app-scoped Riverpod container, captured so JS-channel handlers — which
  /// the WebView can invoke after this screen is disposed — read through it
  /// instead of the widget `ref` (which throws once disposed).
  ProviderContainer? _providersContainer;
  ProviderContainer get _providers => _providersContainer!;

  static const _jsChannelName = 'Usernode';

  void _dispatchPendingSocialPushEvents();
  Future<bool> _seedReadyMainFrame(PrivilegedBridgeLease lease) async {
    final delivered =
        await _privilegedBridgePolicy.runInLease(lease, 'void 0;');
    if (!delivered || !mounted) return false;
    _readyMainFrameLease = lease;
    _dispatchPendingSocialPushEvents();
    return true;
  }

  Future<bool> _runInReadyMainFrame(String javaScriptBody) async {
    final lease = _readyMainFrameLease;
    if (lease == null) return false;
    return _privilegedBridgePolicy.runInLease(lease, javaScriptBody);
  }

  void _replaceRetiredSessionDocument() {
    final delegate = widget.onSessionEnded;
    if (delegate != null) {
      delegate();
      return;
    }
    if (!mounted) return;
    _bridgeAdmissionCoordinator.noteDocumentLoadStarted();
    unawaited(_controller.loadRequest(parseDappUrl(widget.url)));
  }

  // First main-frame load outcome has been reported via
  // widget.onFirstLoadResult (shell first-launch gate). Never reset.
  bool _firstLoadReported = false;

  /// Shared gate for the bridge v3 profile/settings methods: they read and
  /// mutate app-level native state, so only the trusted SV origin may call
  /// them. Rejects the JS promise and returns false for anyone else.
  Future<bool> _requireTrustedChromeOrigin(String id, String method) async {
    if (_activePrivilegedBridgeLease != null) return true;
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method is only available to the dapps home',
    );
    return false;
  }

  /// Extracts a required bool from `payload.args[key]`; rejects the promise
  /// and returns null when missing or mistyped.
  Future<bool?> _requireBoolArg(
    String id,
    Map<String, dynamic> payload,
    String key,
  ) async {
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

  Future<void> _resolveJsPromise({
    required String id,
    required Object? value,
    required String? error,
    Map<String, Object?>? errorInfo,
  }) async {
    final lease = _activePrivilegedBridgeLease;
    if (lease != null) {
      await _privilegedBridgePolicy.resolve(
        lease: lease,
        id: id,
        value: value,
        error: error,
        errorInfo: errorInfo,
      );
      return;
    }
    final js = 'window.__usernodeResolve(${jsonEncode(id)},'
        ' ${jsonEncode(value)}, ${jsonEncode(error)},'
        ' ${jsonEncode(errorInfo)});';
    try {
      await _controller.runJavaScript(js);
    } catch (_) {
      // Ignore callback failures.
    }
  }

  /// The central dispatch has already probed and authorized this exact realm.
  /// Shortcut handlers share that realm-bound lease through the current Zone.
  Future<bool> _isTrustedShortcutOrigin() async {
    return _activePrivilegedBridgeLease != null;
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

  Future<bool> _revalidatePrivilegedBridgeLease(
    String id,
    String method,
  ) async {
    final lease = _activePrivilegedBridgeLease;
    if (lease != null && await _privilegedBridgePolicy.revalidates(lease)) {
      return true;
    }
    await _resolveJsPromise(
      id: id,
      value: null,
      error: '$method was cancelled because the page changed',
    );
    return false;
  }

  /// Privileged admissions resolve into their exact authorizing realm;
  /// ordinary dapp methods retain the existing top-frame response path.
  Future<void> _resolveBridgePromise({
    required String id,
    required Object? value,
    required String? error,
    Map<String, Object?>? errorInfo,
  }) async {
    await _resolveJsPromise(
      id: id,
      value: value,
      error: error,
      errorInfo: errorInfo,
    );
  }

  PrivilegedBridgeLease? get _activePrivilegedBridgeLease =>
      PrivilegedBridgeRequestContext.currentLease;

  Future<void> _resolveClaimedSessionOperation({
    required String id,
    required Map<String, dynamic> payload,
    required String method,
    required FutureOr<Object?> Function(
      SessionIdentityProjection identity,
      SessionOperation operation,
    ) body,
  }) async {
    final lease = _activePrivilegedBridgeLease;
    final claim = payload['realmSessionClaim'];
    if (lease == null ||
        claim is! String ||
        claim.isEmpty ||
        claim.length > 256 ||
        claim.trim() != claim) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: '$method requires the exact native session realm',
        errorInfo: const {'code': 'native_session_realm_mismatch'},
      );
      return;
    }
    if (!await _revalidatePrivilegedBridgeLease(id, method)) return;
    try {
      final value = await widget._nativeSessionBridge.runSessionOperation(
        realmMarker: lease.marker,
        realmSessionClaim: claim,
        body: body,
      );
      await _resolveJsPromise(id: id, value: value, error: null);
    } on NativeSessionException catch (error) {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: error.message,
        errorInfo: {'code': error.code},
      );
    } on SessionAdmissionClosedException {
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The native session is closing',
        errorInfo: const {'code': 'native_session_admission_closed'},
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[Usernode JS-channel] session operation failed '
        'method=$method: $error\n$stackTrace',
      );
      await _resolveJsPromise(
        id: id,
        value: null,
        error: 'The native session operation failed',
        errorInfo: const {'code': 'native_session_operation_failed'},
      );
    }
  }
}

class _DappWebViewScreenState extends _DappWebViewScreenStateBase
    with
        _BridgeAuthNode,
        _BridgeWallet,
        _BridgeShortcuts,
        _BridgeSettings,
        _BridgeSocialPush,
        _BridgeCapture,
        _BridgeDispatch {
  int _widgetNavigationRevision = 0;
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
        limitsNavigationsToAppBoundDomains: widget.appBoundDomainsOnly,
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
          onPageStarted: (_) {
            _bridgeAdmissionCoordinator.noteDocumentLoadStarted();
          },
          onPageFinished: (_) {
            if (!mounted) return;
            _reportFirstLoadResult(true);
            _logServiceWorkerStateForDebug();
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
      );
    _privilegedBridgePolicy = PrivilegedBridgePolicy(
      trustedOrigin: Uri.tryParse(AppConfig.dappsTabUrl),
      allowLocalDevelopment:
          kDebugMode && AppConfig.enableLocalPrivilegedBridge,
      evaluateTopFrame: _controller.runJavaScriptReturningResult,
    );
    _bridgeAdmissionCoordinator = BridgeAdmissionCoordinator(
      policy: _privilegedBridgePolicy,
      markRealmReady: _seedReadyMainFrame,
    );
    unawaited(_controller.loadRequest(parseDappUrl(widget.url)));
    // Android WebView shows no OS file chooser for <input type="file">
    // unless the host app registers one (WebChromeClient.onShowFileChooser)
    // — without this, upload controls in dapps (including cross-origin
    // iframes like staging previews) silently no-op. iOS WKWebView
    // presents its own picker natively, so this is Android-only.
    final platformController = _controller.platform;
    if (platformController is AndroidWebViewController) {
      platformController.setOnShowFileSelector(_showAndroidFileSelector);
    }
    _listenForSocialPushEvents();
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
    if (oldWidget.url == widget.url &&
        oldWidget.navigationRequest == widget.navigationRequest) {
      return;
    }
    final revision = ++_widgetNavigationRevision;
    unawaited(_applyWidgetNavigation(revision));
  }

  Future<void> _applyWidgetNavigation(int revision) async {
    final next = parseDappUrl(widget.url);
    Uri? current;
    try {
      final rawCurrent = await _controller.currentUrl();
      current = rawCurrent == null ? null : Uri.tryParse(rawCurrent);
    } catch (_) {
      current = null;
    }
    if (!mounted || revision != _widgetNavigationRevision) return;
    if (current != null && isSameWebDocument(current, next)) {
      final fragment = jsonEncode(next.fragment);
      await _controller.runJavaScript('''
        (function () {
          var nextHash = $fragment;
          if (window.location.hash.substring(1) === nextHash) {
            window.dispatchEvent(new HashChangeEvent('hashchange', {
              oldURL: window.location.href,
              newURL: window.location.href
            }));
          } else {
            window.location.hash = nextHash;
          }
        })();
      ''').catchError((_) {});
      return;
    }
    await _controller.loadRequest(next);
  }

  /// Presents the OS file picker for a WebView `<input type="file">` tap
  /// and returns the chosen file URIs (empty list = user cancelled).
  Future<List<String>> _showAndroidFileSelector(
    FileSelectorParams params,
  ) async {
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
      Theme.of(context).colorScheme.surfaceContainerLowest,
    );
  }

  @override
  void dispose() {
    _bridgeAdmissionCoordinator.dispose();
    _readyMainFrameLease = null;
    _privilegedBridgePolicy.dispose();
    _disposeSocialPushEvents();
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
        appBar: widget.standalone
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Home',
                  onPressed: _leaveStandaloneBrowser,
                  icon: const Icon(Symbols.home_sharp),
                ),
                title: Text(widget.name),
              )
            : null,
        body: ColoredBox(
          color: colors.surfaceContainerLowest,
          child: widget.standalone
              ? WebViewWidget(controller: _controller)
              : SafeArea(
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
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _leaveStandaloneBrowser() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}
