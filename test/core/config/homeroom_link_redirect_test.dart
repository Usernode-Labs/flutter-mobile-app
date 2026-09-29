import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/homeroom_link_redirect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('preserves encoded paths, duplicate queries and fragments', () {
    const raw = 'https://app.onhomeroom.com/app/a/full/'
        '?path=%2Fpage%3Fx%3D1&tag=a&tag=b#section%20one';
    expect(homeroomWebLink(Uri.parse(raw)).toString(), raw);
    expect(
        homeroomWebLink(Uri.parse(raw.replaceFirst('https:', 'http:')))
            .toString(),
        raw);
    expect(
        homeroomWebLink(Uri.parse('https://app.onhomeroom.com:443/'))
            .toString(),
        'https://app.onhomeroom.com/');
  });

  for (final raw in [
    'https://my.onhomeroom.com/app/a',
    'https://app.onhomeroom.com.evil.test/app/a',
    'https://evil.test/app.onhomeroom.com',
    'https://app.onhomeroom.com@evil.test/',
    'https://evil@app.onhomeroom.com/',
    'https://app.onhomeroom.com:8443/',
    'http://app.onhomeroom.com:443/',
    '//app.onhomeroom.com/app/a',
    'javascript:alert(1)',
    '/app/a',
  ]) {
    test('rejects unverified website URL $raw', () {
      expect(homeroomWebLink(Uri.parse(raw)), isNull);
    });
  }

  late GoRouter router;
  final rendered = <Uri>[];
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> mount(WidgetTester tester, String initial) async {
    binding.platformDispatcher.defaultRouteNameTestValue = initial;
    router = GoRouter(
      initialLocation: initial == '/' ? AppRoutes.home : initial,
      overridePlatformDefaultLocation: true,
      redirect:
          homeroomLinkRedirect(() => router.routeInformationProvider.value.uri),
      routes: [
        GoRoute(path: '/', builder: (_, state) => const Text('home')),
        GoRoute(
            path: AppRoutes.home,
            builder: (_, state) {
              rendered.add(state.uri);
              return Text(state.uri.queryParameters['web'] ?? 'home');
            }),
        GoRoute(
            path: AppRoutes.dappDetail,
            builder: (_, state) => Text('pin ${state.pathParameters['slug']}')),
        GoRoute(
            path: AppRoutes.diagnostics,
            builder: (_, state) => const Text('native diagnostics')),
      ],
    );
    addTearDown(() {
      router.dispose();
      binding.platformDispatcher.clearDefaultRouteNameTestValue();
      rendered.clear();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> deliver(WidgetTester tester, String url) async {
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': url}),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final link in [
    'https://app.onhomeroom.com/app/run-club/dev/issues/42?view=all',
    'https://app.onhomeroom.com/app/run-club/?tag=a&tag=b#comments',
    'https://app.onhomeroom.com#messages',
    'https://app.onhomeroom.com?return_to=%2Fcli-authorize%3Fcode%3Dtest#login',
    'https://app.onhomeroom.com/invite/abcdefghijklmnopqrstuv',
    'https://app.onhomeroom.com/settings/diagnostics',
  ]) {
    testWidgets('cold link opens the exact website destination: $link',
        (tester) async {
      await mount(tester, link);
      expect(rendered.last.queryParameters['web'], link);
      expect(find.text('native diagnostics'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('warm delivery and repeated taps reassert their destinations',
      (tester) async {
    await mount(tester, '/');
    const first = 'https://app.onhomeroom.com/app/a/';
    const second = 'https://app.onhomeroom.com/#messages';
    await deliver(tester, first);
    expect(rendered.last.queryParameters['web'], first);
    final launch = rendered.last.queryParameters['launch'];
    await deliver(tester, first);
    expect(rendered.last.queryParameters['web'], first);
    expect(rendered.last.queryParameters['launch'], isNot(launch));
    await deliver(tester, second);
    expect(rendered.last.queryParameters['web'], second);
  });

  testWidgets('foreign website links cannot select native screens or WebViews',
      (tester) async {
    await mount(tester, '/');
    await deliver(tester, 'https://evil.test/settings/diagnostics');
    expect(find.text('native diagnostics'), findsNothing);
    expect(rendered.last.queryParameters['web'], isNull);
    await deliver(tester, 'https://evil.test/home?web=https%3A%2F%2Fevil.test');
    expect(rendered.last.queryParameters['web'], isNull);
  });

  testWidgets('existing custom app shortcuts still work', (tester) async {
    await mount(tester, '/');
    await deliver(tester, 'homeroom://app/dapps/run-club');
    expect(find.text('pin run-club'), findsOneWidget);
    await deliver(tester, 'homeroom://app/settings/diagnostics');
    expect(find.text('native diagnostics'), findsNothing);
  });
}
