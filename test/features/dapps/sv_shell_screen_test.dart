// The calm launch: one still screen from the tap until the page has painted.
//
// SvShellScreen creates its WebView on the first frame, under a LaunchCover
// that continues the native launch screen, and fades the cover out over
// 150 ms when the page reports `shellPainted`, or at the 3 s cap. On a launch
// that has already passed the first-launch gate there is no "Connecting"
// screen; on the first launch ever the cover also waits for the page to load.
//
// `shellPainted` goes through the real JS channel and dispatch here, so these
// also pin the bridge contract the web shell relies on.

import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/config/sv_shell_gate.dart';
import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/features/dapps/sv_shell_screen.dart';
import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/native_session_bridge_ingress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

final _url = AppConfig.platformBaseUrl;

void main() {
  late _WebViewPlatform platform;
  late WebViewPlatform? originalPlatform;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LaunchCoverClock.reset();
    SvShellGateStorage.passed = true;
    originalPlatform = WebViewPlatform.instance;
    platform = _WebViewPlatform();
    WebViewPlatform.instance = platform;
  });

  tearDown(() {
    SvShellGateStorage.passed = false;
    if (originalPlatform != null) WebViewPlatform.instance = originalPlatform;
  });

  Widget shell({String? link, String? launch}) => ProviderScope(
        child: MaterialApp(
          theme: ThemeData(extensions: DesignSystemTheme.standardExtensions()),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SvShellScreen(
            initialWebUrl: link,
            navigationRequest: launch,
            nativeSessionBridge: _NativeSession(),
            sessionAccess: _SessionAccess(),
          ),
        ),
      );

  final cover = find.byKey(SvShellScreen.coverKey);
  final connecting = find.byKey(LaunchCover.connectingKey);

  bool lifting(WidgetTester tester) =>
      tester.widget<IgnorePointer>(cover).ignoring;

  /// Sends a bridge call the way the page does and returns the script that
  /// resolved it.
  Future<String> call(
    WidgetTester tester,
    String method, {
    Map<String, Object?> args = const {},
  }) async {
    final id = 'req-${platform.controller.scripts.length}';
    platform.controller.channel.onMessageReceived(JavaScriptMessage(
      message: jsonEncode({'id': id, 'method': method, 'args': args}),
    ));
    // One pump runs the dispatch to its reply, the next builds what it set.
    await tester.pump();
    await tester.pump();
    return platform.controller.scripts.lastWhere(
      (s) => s.contains('__usernodeResolve(${jsonEncode(id)}'),
    );
  }

  /// The fade's first frame starts its clock, and it is done once MORE than
  /// its duration has passed; its end drops the cover.
  Future<void> finishFade(WidgetTester tester) async {
    await tester.pump();
    await tester
        .pump(SvShellScreen.coverFade + const Duration(milliseconds: 1));
    await tester.pump();
  }

  group('a launch past the first-launch gate', () {
    testWidgets('creates the WebView on its first frame, under a still cover',
        (tester) async {
      await tester.pumpWidget(shell());

      expect(platform.controller.loads, [Uri.parse(_url)]);
      expect(find.byType(WebViewWidget), findsOneWidget);
      expect(cover, findsOneWidget);
      expect(lifting(tester), isFalse);
      // No gate: no spinner, no "Connecting", no offline message.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(connecting, findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shellPainted fades the cover into the page over 150 ms',
        (tester) async {
      await tester.pumpWidget(shell());
      await tester.pump(const Duration(milliseconds: 800));

      final resolved = await call(tester, 'shellPainted');
      expect(resolved, contains(', true, null'));
      expect(lifting(tester), isTrue, reason: 'taps reach the page at once');
      expect(
          tester
              .widget<AnimatedOpacity>(
                find.descendant(
                    of: cover, matching: find.byType(AnimatedOpacity)),
              )
              .opacity,
          0);
      expect(cover, findsOneWidget, reason: 'still fading');

      await finishFade(tester);
      expect(cover, findsNothing);
      expect(platform.controller.loads, [Uri.parse(_url)]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the cover lifts at the 3 s cap without shellPainted',
        (tester) async {
      await tester.pumpWidget(shell());

      await tester.pump(const Duration(milliseconds: 2400));
      expect(connecting, findsNothing);
      await tester.pump(const Duration(milliseconds: 200));
      expect(connecting, findsOneWidget, reason: 'up for 2.5 s: say why');
      expect(lifting(tester), isFalse);

      await tester.pump(const Duration(milliseconds: 400));
      expect(lifting(tester), isTrue);
      await finishFade(tester);
      expect(cover, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('repeat shellPainted calls are harmless', (tester) async {
      await tester.pumpWidget(shell());

      expect(await call(tester, 'shellPainted'), contains(', true, null'));
      expect(await call(tester, 'shellPainted'), contains(', true, null'));
      await finishFade(tester);
      expect(cover, findsNothing);
      // A later document's call finds no cover to lift.
      expect(await call(tester, 'shellPainted'), contains(', true, null'));
      await tester.pump(const Duration(seconds: 4));
      expect(cover, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a warm link navigation never brings the cover back',
        (tester) async {
      const first = 'https://app.onhomeroom.com/app/run-club';
      const second = 'https://app.onhomeroom.com/app/book-club';
      await tester.pumpWidget(shell(link: first, launch: 'web-1'));
      await call(tester, 'shellPainted');
      await finishFade(tester);
      final controller = platform.controller;

      await tester.pumpWidget(shell(link: second, launch: 'web-2'));
      await tester.pump();
      expect(platform.controller, same(controller));
      expect(controller.loads.last, Uri.parse(second));
      expect(cover, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('shellPainted', () {
    testWidgets('is advertised in getBridgeInfo', (tester) async {
      await tester.pumpWidget(shell());
      platform.controller.channel.onMessageReceived(const JavaScriptMessage(
        message: '{"id":"info","method":"getBridgeInfo","args":{}}',
      ));
      // The reply waits on platform channels (package info, Live Activity
      // support), which settle only in real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      final reply = platform.controller.scripts.lastWhere(
        (s) => s.contains('__usernodeResolve("info"'),
      );
      expect(reply, contains('"shellPainted"'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('from an untrusted top frame is refused and changes nothing',
        (tester) async {
      platform.topFrameUrl = 'https://evil.test/';
      await tester.pumpWidget(shell());

      final resolved = await call(tester, 'shellPainted');
      expect(resolved, contains('null, "shellPainted is only available'));
      expect(lifting(tester), isFalse);

      // The cap still ends the launch.
      await tester.pump(SvShellScreen.coverCap);
      expect(lifting(tester), isTrue);
      await finishFade(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the first launch ever', () {
    setUp(() => SvShellGateStorage.passed = false);

    testWidgets('keeps the cover past the cap until the page has loaded',
        (tester) async {
      await tester.pumpWidget(shell());
      expect(find.byType(WebViewWidget), findsOneWidget);

      // Painted before the load finished, and the cap long gone: still up.
      await call(tester, 'shellPainted');
      await tester.pump(const Duration(seconds: 5));
      expect(lifting(tester), isFalse);
      expect(connecting, findsOneWidget);

      platform.navigation.onPageFinished!(_url);
      await tester.pump();
      expect(lifting(tester), isTrue);
      await finishFade(tester);
      expect(cover, findsNothing);
      expect(SvShellGateStorage.passed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('sv_shell_first_load_ok'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('waits for shellPainted after the load, within the cap',
        (tester) async {
      await tester.pumpWidget(shell());
      platform.navigation.onPageFinished!(_url);
      await tester.pump(const Duration(milliseconds: 500));
      expect(lifting(tester), isFalse);

      await call(tester, 'shellPainted');
      expect(lifting(tester), isTrue);
      await finishFade(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('that fails offers a retry under the mark', (tester) async {
      await tester.pumpWidget(shell());
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SvShellScreen)),
      );

      platform.navigation.onWebResourceError!(const WebResourceError(
        errorCode: -1009,
        description: 'The Internet connection appears to be offline.',
        isForMainFrame: true,
      ));
      await tester.pump();
      expect(find.text(l10n.svShellOfflineMessage), findsOneWidget);
      expect(connecting, findsNothing);

      await tester.pump(const Duration(seconds: 5));
      expect(lifting(tester), isFalse, reason: 'no cap on a failed gate');

      final failed = platform.controller;
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      expect(platform.controller, isNot(same(failed)));
      expect(platform.controller.loads, [Uri.parse(_url)]);
      expect(find.text(l10n.svShellOfflineMessage), findsNothing);
      expect(cover, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _NativeSession extends Fake implements NativeSessionBridgeIngress {
  final retirements = StreamController<void>.broadcast(sync: true);

  @override
  bool terminallyRetired = false;

  @override
  Stream<void> get terminalRetirements => retirements.stream;
}

class _SessionAccess extends Fake implements SessionFeatureAccessView {}

class _WebViewPlatform extends WebViewPlatform {
  late _Controller controller;
  late _NavigationDelegate navigation;

  /// The top frame's URL as the realm probe reports it.
  String topFrameUrl = _url;

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(
    PlatformWebViewCookieManagerCreationParams params,
  ) =>
      _Cookies(params);

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) =>
      controller = _Controller(params, this);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) =>
      navigation = _NavigationDelegate(params);

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
  _Controller(super.params, this.owner) : super.implementation();
  final _WebViewPlatform owner;
  late JavaScriptChannelParams channel;
  final scripts = <String>[];
  final loads = <Uri>[];

  @override
  Future<void> runJavaScript(String script) async {
    scripts.add(script);
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (script.contains('return marker.length')) {
      return '5:realm${owner.topFrameUrl}';
    }
    return true;
  }

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

  PageEventCallback? onPageFinished;
  WebResourceErrorCallback? onWebResourceError;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {
    this.onPageFinished = onPageFinished;
  }

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {
    this.onWebResourceError = onWebResourceError;
  }
}

class _Cookies extends PlatformWebViewCookieManager {
  _Cookies(super.params) : super.implementation();
}
