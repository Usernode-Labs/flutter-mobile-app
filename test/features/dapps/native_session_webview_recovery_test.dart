import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

final _url = AppConfig.platformBaseUrl;

void main() {
  late _WebViewPlatform platform;
  late _NativeSession session;
  late WebViewPlatform? originalPlatform;

  setUp(() {
    originalPlatform = WebViewPlatform.instance;
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
    session = _NativeSession(platform.events);
  });

  tearDown(() async {
    if (originalPlatform != null) WebViewPlatform.instance = originalPlatform;
    await session.retirements.close();
  });

  Widget app({String? url}) => ProviderScope(
        child: MaterialApp(
          home: DappWebViewScreen(
            url: url ?? _url,
            name: 'Usernode',
            nativeSessionBridge: session,
            sessionAccess: _SessionAccess(),
          ),
        ),
      );

  Future<void> requestLogout(WidgetTester tester) async {
    final controller = platform.controller;
    controller.channel.onMessageReceived(const JavaScriptMessage(
      message: '{"id":"capability","method":"getPrivilegedBridgeCapability"}',
    ));
    await tester.pump();
    expect(controller.capability, isNotNull);
    controller.channel.onMessageReceived(JavaScriptMessage(
      message: jsonEncode({
        'id': 'logout',
        'method': 'logout',
        'privilegedCapability': controller.capability,
      }),
    ));
    await tester.pump();
  }

  testWidgets('logout deletes WebView data after retirement and before reload',
      (tester) async {
    await tester.pumpWidget(app());
    platform.events.clear();
    await requestLogout(tester);
    expect(platform.events, [
      'retire',
      'cookies',
      'storage',
      'cache',
      'ack',
      'load',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cookie deletion failure does not acknowledge or reload; retry succeeds',
      (tester) async {
    await tester.pumpWidget(app());
    platform.failCookies = true;
    platform.events.clear();
    await requestLogout(tester);
    expect(platform.events, ['retire', 'cookies', 'error']);
    platform.failCookies = false;
    platform.events.clear();
    await requestLogout(tester);
    expect(platform.events, [
      'retire',
      'cookies',
      'storage',
      'cache',
      'ack',
      'load',
    ]);
    expect(tester.takeException(), isNull);
  });

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
  _NativeSession(this.events);
  final List<String> events;

  @override
  Future<void> logoutNativeSession({required String realmMarker}) async {
    events.add('retire');
  }

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
  final events = <String>[];
  bool failCookies = false;

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      _Cookies(params, this);

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      controller = _Controller(params, events);

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
  _Controller(super.params, this.events) : super.implementation();
  final List<String> events;
  late JavaScriptChannelParams channel;
  String? capability;

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script.contains('return marker.length')) return '5:realm$_url';
    final match =
        RegExp(r'resolver\((.*?)\);', dotAll: true).firstMatch(script);
    if (match != null) {
      final args = jsonDecode('[${match.group(1)}]') as List;
      if (args[0] == 'capability') capability = args[1] as String;
      if (args[0] == 'logout') events.add(args[2] == null ? 'ack' : 'error');
    }
    return true;
  }

  @override
  Future<void> clearLocalStorage() async {
    events.add('storage');
  }

  @override
  Future<void> clearCache() async {
    events.add('cache');
  }

  final loads = <Uri>[];

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    events.add('load');
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
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

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

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params, this.owner) : super.implementation();
  final _WebViewPlatform owner;

  @override
  Future<bool> clearCookies() async {
    owner.events.add('cookies');
    if (owner.failCookies) throw StateError('cookie store unavailable');
    return true;
  }
}
