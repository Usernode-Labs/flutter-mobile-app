// The launch cover continues the native launch screen, so it must draw what
// LaunchScreen.storyboard draws: the app ground, and the mark unscaled
// (128pt) at the centre of the whole screen, black on light and cream on
// dark. Anything else is a jump the moment Flutter's first frame lands.

import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    LaunchCoverClock.reset();
    AppearanceStorage.background = null;
  });

  Widget app(Widget home, {Brightness brightness = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: DesignSystemTheme.standardExtensions(),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  final mark = find.byType(Image);
  final connecting = find.byKey(LaunchCover.connectingKey);

  Color ground(WidgetTester tester) => tester
      .widget<Material>(
        find.descendant(
          of: find.byType(LaunchCover),
          matching: find.byType(Material),
        ),
      )
      .color!;

  testWidgets(
      'draws the launch image: the mark unscaled, centred on the '
      'whole screen, black on the light ground', (tester) async {
    await tester.pumpWidget(app(const SplashScreen()));

    final image = tester.widget<Image>(mark);
    expect((image.image as AssetImage).assetName, 'assets/brand/mark.png');
    expect(image.height, 128);
    expect(image.color, Colors.black);
    expect(ground(tester), AppearanceStorage.lightGround);
    expect(
      tester.getCenter(mark),
      tester.getCenter(find.byType(LaunchCover)),
      reason: 'the storyboard centres on the root view, not the safe area',
    );
    expect(tester.getSize(find.byType(LaunchCover)),
        tester.view.physicalSize / tester.view.devicePixelRatio);
  });

  testWidgets('is cream on the dark ground', (tester) async {
    await tester.pumpWidget(
      app(const SplashScreen(), brightness: Brightness.dark),
    );
    expect(tester.widget<Image>(mark).color, const Color(0xFFFFFEF4));
    expect(ground(tester), AppearanceStorage.darkGround);
  });

  testWidgets('is still: no fade, scale, slide, title or spinner',
      (tester) async {
    await tester.pumpWidget(app(const SplashScreen()));
    expect(tester.binding.transientCallbackCount, 0, reason: 'no ticker');
    Finder inCover(Type type) => find.descendant(
          of: find.byType(LaunchCover),
          matching: find.byType(type),
        );
    expect(inCover(FadeTransition), findsNothing);
    expect(inCover(ScaleTransition), findsNothing);
    expect(inCover(SlideTransition), findsNothing);
    expect(inCover(CircularProgressIndicator), findsNothing);
    expect(inCover(Text), findsNothing);
  });

  testWidgets('says Connecting after 2.5 s, counted from the first cover',
      (tester) async {
    // The splash, then the shell's cover: one screen to the user.
    await tester.pumpWidget(app(const LaunchCover(key: ValueKey('splash'))));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(app(const LaunchCover(key: ValueKey('shell'))));
    await tester.pump(const Duration(milliseconds: 400));
    expect(connecting, findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(connecting, findsOneWidget);
    expect(find.text('Connecting to Homeroom…'), findsOneWidget);
  });

  testWidgets('a message appears under the mark without moving it',
      (tester) async {
    await tester.pumpWidget(app(const LaunchCover()));
    final before = tester.getCenter(mark);

    await tester.pumpWidget(app(const LaunchCover(message: Text('Offline'))));
    expect(find.text('Offline'), findsOneWidget);
    expect(tester.getCenter(mark), before);
    expect(
      tester.getTopLeft(find.text('Offline')).dy,
      greaterThan(before.dy + LaunchCover.markHeight / 2),
    );
  });

  testWidgets('precacheMark completes', (tester) async {
    await tester.runAsync(
      () => LaunchCover.precacheMark().timeout(const Duration(seconds: 5)),
    );
  });
}
