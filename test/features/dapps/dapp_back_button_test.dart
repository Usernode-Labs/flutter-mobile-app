// Android back, at the root of the SV shell (usernode#1521).
//
// The request: "inside an app -> dashboard; on dashboard -> exit". The first
// half is the webview's own history, because opening an app is a hash
// navigation inside the page. The second half did nothing at all.
//
// It did nothing for a reason worth keeping written down. The fallback was
// `context.go(AppRoutes.home)`, and `/home` IS this screen — LAYOUT.md: "the
// native app is chromeless: /home renders the SV webview full-bleed". So the
// press was consumed and the app navigated to where the user already was.
// A back button that silently does nothing reads as broken, which is exactly
// how it was reported.
//
// Run with: flutter test test/features/dapps/dapp_back_button_test.dart

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

final _url = AppConfig.platformBaseUrl;

void main() {
  late _WebViewPlatform platform;
  late WebViewPlatform? originalPlatform;
  late List<String> systemCalls;

  setUp(() {
    originalPlatform = WebViewPlatform.instance;
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    systemCalls = <String>[];
    // SystemNavigator.pop() goes out over this channel; catching it here is
    // how the test sees "the app asked the system to leave".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    if (originalPlatform != null) WebViewPlatform.instance = originalPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget app() => ProviderScope(
        child: MaterialApp(
          home: DappWebViewScreen(
            url: _url,
            name: 'Usernode',
            nativeSessionBridge: _NativeSession(),
            sessionAccess: _SessionAccess(),
          ),
        ),
      );

  /// The system back press, as Android delivers it to PopScope.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('inside an app, back walks the page history and stays in',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    platform.controller.backAvailable = true;
    await pressBack(tester);

    expect(platform.controller.wentBack, isTrue,
        reason:
            'a page with history behind it should go back inside the webview');
    expect(systemCalls, isNot(contains('SystemNavigator.pop')),
        reason: 'going back inside an app must never leave the app');
  });

  testWidgets('on the dashboard, back leaves the app instead of doing nothing',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Webview at its own root, and this screen is the root route — which is
    // the dashboard, since SvShellScreen is only mounted at `/` and `/home`.
    platform.controller.backAvailable = false;
    await pressBack(tester);

    expect(platform.controller.wentBack, isFalse);
    expect(systemCalls, contains('SystemNavigator.pop'),
        reason: 'back on the dashboard must exit, not silently re-enter /home');
  });
}

class _NativeSession extends Fake implements NativeSessionBridgeIngress {}

class _SessionAccess extends Fake implements SessionFeatureAccessView {}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      _Cookies(params);

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      controller = _Controller(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      _NavigationDelegate(params);

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) =>
      _WebView(params);
}

class _WebView extends PlatformWebViewWidget {
  _WebView(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _NavigationDelegate extends PlatformNavigationDelegate {
  _NavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
      NavigationRequestCallback onNavigationRequest) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}
  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}
  @override
  Future<void> setOnWebResourceError(
      WebResourceErrorCallback onWebResourceError) async {}
}

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();

  bool backAvailable = false;
  bool wentBack = false;

  @override
  Future<bool> canGoBack() async => backAvailable;

  @override
  Future<void> goBack() async {
    wentBack = true;
  }

  // Everything the screen touches on the way up, stubbed to nothing.
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
      PlatformNavigationDelegate handler) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}
  @override
  Future<void> setUserAgent(String? userAgent) async {}
  @override
  Future<void> setBackgroundColor(Color color) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  @override
  Future<void> runJavaScript(String script) async {}
  @override
  Future<Object> runJavaScriptReturningResult(String script) async => true;
  @override
  Future<String?> currentUrl() async => _url;
  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage) onConsoleMessage,
  ) async {}
  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest) onJavaScriptAlertDialog,
  ) async {}
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();

  @override
  Future<bool> clearCookies() async => true;
}
