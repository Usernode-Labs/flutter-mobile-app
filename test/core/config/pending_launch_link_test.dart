import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/homeroom_link_redirect.dart';
import 'package:crypto_mobile_app/core/config/pending_launch_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const codec = JSONMethodCodec();
  const link = 'https://app.onhomeroom.com/mail/c/abc/0?s=sig';
  const splash = MaterialApp(home: Text('splash'));

  /// Delivers [url] as the engine does and returns its raw reply: iOS
  /// reopens a universal link in Safari unless that reply decodes to `true`.
  Future<ByteData> deliver(WidgetTester tester, String url) async {
    ByteData? reply;
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': url}),
      ),
      (data) => reply = data,
    );
    await tester.pump();
    return reply!;
  }

  PendingLaunchLink observe() {
    final pending = PendingLaunchLink();
    binding.addObserver(pending);
    addTearDown(() => binding.removeObserver(pending));
    return pending;
  }

  final rendered = <Uri>[];
  GoRouter routerFrom(String initial) {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: initial,
      overridePlatformDefaultLocation: true,
      redirect:
          homeroomLinkRedirect(() => router.routeInformationProvider.value.uri),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, state) {
            rendered.add(state.uri);
            return Text(state.uri.queryParameters['web'] ?? 'home');
          },
        ),
      ],
    );
    addTearDown(() {
      router.dispose();
      rendered.clear();
    });
    return router;
  }

  testWidgets('without it, a link during the boot splash goes unhandled',
      (tester) async {
    await tester.pumpWidget(splash);
    final reply = await deliver(tester, link);
    expect(
        () => codec.decodeEnvelope(reply), throwsA(isA<PlatformException>()));
    tester.takeException();
  });

  testWidgets('a link during the boot splash is claimed and kept',
      (tester) async {
    final pending = observe();
    await tester.pumpWidget(splash);

    expect(
      codec
          .decodeEnvelope(await deliver(tester, 'https://app.onhomeroom.com/')),
      isTrue,
    );
    expect(codec.decodeEnvelope(await deliver(tester, link)), isTrue);
    expect(tester.takeException(), isNull);
    expect(find.text('splash'), findsOneWidget);
    expect(pending.close(), link, reason: 'the newest link wins');
  });

  testWidgets('the router starts from the kept link', (tester) async {
    final pending = observe();
    await tester.pumpWidget(splash);
    await deliver(tester, link);

    final launchLink = pending.close()!;
    await tester
        .pumpWidget(MaterialApp.router(routerConfig: routerFrom(launchLink)));
    await tester.pumpAndSettle();

    expect(rendered.last.queryParameters['web'], link);
    expect(tester.takeException(), isNull);
  });

  testWidgets('once closed, links reach the router as before', (tester) async {
    final pending = observe();
    expect(pending.close(), isNull);
    await tester.pumpWidget(
        MaterialApp.router(routerConfig: routerFrom(AppRoutes.home)));
    await tester.pumpAndSettle();

    expect(codec.decodeEnvelope(await deliver(tester, link)), isTrue);
    await tester.pumpAndSettle();
    expect(rendered.last.queryParameters['web'], link);
    expect(pending.close(), isNull);
  });
}
