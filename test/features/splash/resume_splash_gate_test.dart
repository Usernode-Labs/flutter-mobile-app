import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/splash/widgets/resume_splash_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var taps = 0;
  setUp(() => taps = 0);

  Widget host({required bool pending}) => MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: DesignSystemTheme.standardExtensions(
            semanticColors: AppSemanticColors.light(),
          ),
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ResumeSplashGate(
          pending: pending,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const Text('content'),
          ),
        ),
      );

  final splash = find.byKey(ResumeSplashGate.splashKey);

  testWidgets('fast resume validation never shows the splash', (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay ~/ 2);
    expect(splash, findsNothing);

    await tester.pumpWidget(host(pending: false));
    await tester.pump(ResumeSplashGate.showDelay * 2);
    expect(splash, findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('slow resume validation shows the splash until it settles',
      (tester) async {
    await tester.pumpWidget(host(pending: false));
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay);
    await tester.pump();
    expect(splash, findsOneWidget);

    await tester.pumpWidget(host(pending: false));
    await tester.pump();
    expect(splash, findsNothing);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('the splash carries the tinted wordmark and a loading label',
      (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay);
    await tester.pump();

    final image = tester.widget<Image>(
      find.descendant(of: splash, matching: find.byType(Image)),
    );
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/wordmark.png',
    );
    // Tinted from one transparent master rather than shipped per appearance,
    // so a dark-mode regression here would show as a black-on-black mark.
    expect(image.color, isNotNull);
    expect(
      find.descendant(of: splash, matching: find.text('Loading...')),
      findsOneWidget,
    );
  });

  testWidgets('a new resume restarts the delay', (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay ~/ 2);
    await tester.pumpWidget(host(pending: false));
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay ~/ 2);
    expect(splash, findsNothing);

    await tester.pump(ResumeSplashGate.showDelay ~/ 2);
    await tester.pump();
    expect(splash, findsOneWidget);
  });

  testWidgets('pending validation blocks input', (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.tapAt(tester.getCenter(find.byType(ResumeSplashGate)));
    expect(taps, 0);

    await tester.pumpWidget(host(pending: false));
    await tester.pump();
    await tester.tap(find.text('content'));
    expect(taps, 1);
  });

  testWidgets('a validation that never settles releases the UI at maxBlock',
      (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay);
    await tester.pump();
    expect(splash, findsOneWidget);

    await tester.pump(ResumeSplashGate.maxBlock);
    await tester.pump();
    expect(splash, findsNothing);
    await tester.tap(find.text('content'));
    expect(taps, 1);
  });

  testWidgets('a new resume after a timed-out one blocks again',
      (tester) async {
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.maxBlock);
    await tester.pumpWidget(host(pending: false));
    await tester.pumpWidget(host(pending: true));
    await tester.pump(ResumeSplashGate.showDelay);
    await tester.pump();
    expect(splash, findsOneWidget);
    await tester.tapAt(tester.getCenter(find.byType(ResumeSplashGate)));
    expect(taps, 0);
  });
}
