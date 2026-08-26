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
import 'package:crypto_mobile_app/core/widgets/tx_confirmation_page.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart'
    show AuthSession;
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart'
    show
        authRepositoryProvider,
        authStatusProvider,
        identityProvider,
        signOutCompletionProvider;
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart'
    show accountReconciliationStatusProvider, identityDriverProvider;
import 'package:crypto_mobile_app/features/dapps/home_shortcuts_channel.dart';
import 'package:crypto_mobile_app/features/dapps/bridge_admission_coordinator.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';
import 'package:crypto_mobile_app/features/dapps/native_screen_capture.dart';
import 'package:crypto_mobile_app/features/dapps/node_status_snapshot.dart';
import 'package:crypto_mobile_app/features/dapps/privileged_bridge_policy.dart';
import 'package:crypto_mobile_app/features/dapps/session_bound_auth_status.dart';
import 'package:crypto_mobile_app/features/dapps/submit_transaction_contract.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart'
    show SocialPushState;
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/staking_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/zk_challenge_reset.dart'
    show resetChallengeState;
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart'
    show zkPassportFlowControllerProvider;
import 'package:crypto_mobile_app/src/rust/account.dart' as frb_account;
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;
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

  const DappWebViewScreen({
    super.key,
    required this.url,
    required this.name,
    this.navigationRequest,
    this.appBoundDomainsOnly = true,
    this.standalone = false,
    this.onSessionEnded,
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
  late final PrivilegedBridgePolicy _privilegedBridgePolicy;
  late final SessionHandoffGate _sessionHandoffGate;
  late final BridgeAdmissionCoordinator _bridgeAdmissionCoordinator;
  PrivilegedBridgeLease? _readyMainFrameLease;

  /// The app-scoped Riverpod container, captured so JS-channel handlers — which
  /// the WebView can invoke after this screen is disposed — read through it
  /// instead of the widget `ref` (which throws once disposed).
  ProviderContainer? _providersContainer;
  ProviderContainer get _providers => _providersContainer!;

  static const _jsChannelName = 'Usernode';

  void _dispatchPendingSocialPushEvents();
  void _recordReadySocialPushReplay(
    PrivilegedBridgeLease lease,
    int foregroundRevision,
  );
  Map<String, dynamic> _nodeStatusSnapshot();
  Map<String, dynamic> _authStatusSnapshot();

  String _readyMainFrameReplayScript({
    required SocialPushService service,
    required int foregroundRevision,
    required bool canReplayForeground,
  }) {
    final script = StringBuffer()
      ..write('window.dispatchEvent(new CustomEvent(')
      ..write(jsonEncode('usernode:node-status'))
      ..write(', { detail: ${jsonEncode(_nodeStatusSnapshot())} }));')
      ..write('window.dispatchEvent(new CustomEvent(')
      ..write(jsonEncode('usernode:auth-status'))
      ..write(', { detail: ${jsonEncode(_authStatusSnapshot())} }));')
      ..write('window.dispatchEvent(new CustomEvent(')
      ..write(jsonEncode('usernode:social-push-native-state-changed'))
      ..write('));');
    if (service.hasPendingTap) {
      script
        ..write('window.dispatchEvent(new CustomEvent(')
        ..write(jsonEncode('usernode:social-push-pending'))
        ..write('));');
    }
    if (foregroundRevision > 0 && canReplayForeground) {
      script
        ..write('window.dispatchEvent(new CustomEvent(')
        ..write(jsonEncode('usernode:social-push-foreground'))
        ..write('));');
    }
    return script.toString();
  }

  Future<bool> _seedReadyMainFrame(PrivilegedBridgeLease lease) async {
    // The trusted shell calls markPrivilegedBridgeReady only after installing
    // its native-event listeners. The handler binds this lease to that exact
    // realm before replaying state, without relying on WebView finish callbacks.
    final service = SocialPushService.instance;
    final foregroundRevision = service.foregroundInvalidationRevision;
    final canReplayForeground = !_sessionHandoffGate.isAuthenticatedBlocked;
    final delivered = await _privilegedBridgePolicy.runInLease(
      lease,
      _readyMainFrameReplayScript(
        service: service,
        foregroundRevision: foregroundRevision,
        canReplayForeground: canReplayForeground,
      ),
    );
    if (!delivered || !mounted) return false;
    _readyMainFrameLease = lease;
    _recordReadySocialPushReplay(
      lease,
      canReplayForeground ? foregroundRevision : 0,
    );

    // Auth/node/push state can advance while the first guarded evaluation is
    // awaiting the WebView. Snapshot it again only after installing this lease
    // and require that authoritative replay to land before acknowledging page
    // readiness. Live transitions that follow are queued behind this script in
    // the same exact realm.
    final latestForegroundRevision = service.foregroundInvalidationRevision;
    final latestCanReplayForeground =
        !_sessionHandoffGate.isAuthenticatedBlocked;
    final replayed = await _privilegedBridgePolicy.runInLease(
      lease,
      _readyMainFrameReplayScript(
        service: service,
        foregroundRevision: latestForegroundRevision,
        canReplayForeground: latestCanReplayForeground,
      ),
    );
    if (!replayed || !mounted || _readyMainFrameLease?.marker != lease.marker) {
      if (_readyMainFrameLease?.marker == lease.marker) {
        _readyMainFrameLease = null;
      }
      return false;
    }
    _recordReadySocialPushReplay(
      lease,
      latestCanReplayForeground ? latestForegroundRevision : 0,
    );
    // Retained taps or a foreground revision may have arrived during the
    // second evaluation. Their dispatchers are idempotent/coalesced.
    _dispatchPendingSocialPushEvents();
    return true;
  }

  Future<bool> _runInReadyMainFrame(String javaScriptBody) async {
    final lease = _readyMainFrameLease;
    if (lease == null) return false;
    return _privilegedBridgePolicy.runInLease(lease, javaScriptBody);
  }

  bool _admitAuthenticatedSession(Identity identity) {
    if (!_sessionHandoffGate.admitAuthenticated(identity)) return false;
    _dispatchPendingSocialPushEvents();
    return true;
  }

  bool _admitWalletSession(Identity identity) =>
      _sessionHandoffGate.admitWallet(identity);

  bool _admitAnonymousSession() {
    if (!_sessionHandoffGate.admitAnonymous()) return false;
    _dispatchPendingSocialPushEvents();
    return true;
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
    final lease = _activePrivilegedBridgeLease;
    if (lease != null) {
      await _privilegedBridgePolicy.resolve(
        lease: lease,
        id: id,
        value: value,
        error: error,
      );
      return;
    }
    final js = 'window.__usernodeResolve(${jsonEncode(id)},'
        ' ${jsonEncode(value)}, ${jsonEncode(error)});';
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
  }) async {
    await _resolveJsPromise(id: id, value: value, error: error);
  }

  PrivilegedBridgeLease? get _activePrivilegedBridgeLease =>
      PrivilegedBridgeRequestContext.currentLease;
}

class _DappWebViewScreenState extends _DappWebViewScreenStateBase
    with
        WidgetsBindingObserver,
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
    _sessionHandoffGate = SessionHandoffGate(
      initiallyBlocked: !widget.standalone,
    );
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
      sessionGate: _sessionHandoffGate,
      admitAnonymousSession: _admitAnonymousSession,
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
    ref.listenManual(identityProvider, (previous, next) {
      if (previous?.phase == next.phase &&
          previous?.address == next.address &&
          previous?.participantId == next.participantId &&
          previous?.epoch == next.epoch) {
        return;
      }
      _dispatchAuthStatusEvent();
      if (next.phase == IdentityPhase.ready) {
        _admitWalletSession(next);
        unawaited(_ensureNodeForStandaloneDappEntry());
      } else if (next.phase == IdentityPhase.reconciling) {
        _sessionHandoffGate.restrictWallet(next);
      } else if (!next.isAuthenticated) {
        _sessionHandoffGate.begin();
      }
    });
    // A settled sign-out must leave no trusted document rendering the retired
    // session. This is the shared WebView owner, so it happens here for every
    // realm — the SV shell just supplies a colder replacement than an in-place
    // load can be.
    ref.listenManual<int>(signOutCompletionProvider, (previous, next) {
      if (previous != null && next <= previous) return;
      final delegate = widget.onSessionEnded;
      if (delegate != null) {
        delegate();
        return;
      }
      if (!mounted) return;
      _bridgeAdmissionCoordinator.noteDocumentLoadStarted();
      unawaited(_controller.loadRequest(parseDappUrl(widget.url)));
    });
    ref.listenManual(accountReconciliationStatusProvider, (previous, next) {
      if (previous == next) return;
      _dispatchAuthStatusEvent();
    });
    _listenForSocialPushEvents();
    unawaited(_ensureNodeForStandaloneDappEntry());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    // The identity itself may not change while the WebView is backgrounded.
    // Re-emit authoritative native state so a page whose secure handoff
    // previously failed can retry after the app returns to the foreground.
    _dispatchAuthStatusEvent();
    _dispatchPendingSocialPushEvents();
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
    WidgetsBinding.instance.removeObserver(this);
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
