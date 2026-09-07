import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

const _url = 'https://social-vibecoding.usernodelabs.org/';

void main() {
  late _WebViewPlatform platform;
  late _NativeSession session;
  late WebViewPlatform? originalPlatform;

  setUp(() {
    originalPlatform = WebViewPlatform.instance;
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    session = _NativeSession();
  });

  tearDown(() async {
    if (originalPlatform != null) WebViewPlatform.instance = originalPlatform;
    await session.retirements.close();
  });

  Widget app({String url = _url}) => ProviderScope(
        child: MaterialApp(
          home: DappWebViewScreen(
            url: url,
            name: 'Usernode',
            nativeSessionBridge: session,
            sessionAccess: _SessionAccess(),
          ),
        ),
      );

  testWidgets('native retirement preserves the web document and navigation',
      (tester) async {
    await tester.pumpWidget(app());
    final controller = platform.controller;
    expect(controller.loads, [Uri.parse(_url)]);
    expect(find.byType(WebViewWidget), findsOneWidget);

    session.retire();
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(platform.controller, same(controller));
    expect(controller.loads, [Uri.parse(_url)]);

    await tester.pumpWidget(app(url: '${_url}help'));
    await tester.pump();
    expect(controller.loads.last, Uri.parse('${_url}help'));
    expect(platform.controller, same(controller));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a previously retired native session still loads the web app',
      (tester) async {
    session.retire();

    await tester.pumpWidget(app());
    await tester.pump();

    expect(platform.controller.loads, [Uri.parse(_url)]);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NativeSession extends Fake implements NativeSessionBridgeIngress {
  final retirements = StreamController<void>.broadcast(sync: true);

  @override
  bool terminallyRetired = false;

  @override
  Stream<void> get terminalRetirements => retirements.stream;

  void retire() {
    terminallyRetired = true;
    retirements.add(null);
  }
}

class _SessionAccess extends Fake implements SessionFeatureAccessView {}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;

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

class _Controller extends PlatformWebViewController {
  _Controller(super.params) : super.implementation();

  final loads = <Uri>[];

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loads.add(params.uri);
  }

  @override
  Future<String?> currentUrl() async => loads.lastOrNull?.toString();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setBackgroundColor(Color color) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage) onConsoleMessage,
  ) async {}

  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest) onJavaScriptAlertDialog,
  ) async {}

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class _NavigationDelegate extends PlatformNavigationDelegate {
  _NavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}
}
