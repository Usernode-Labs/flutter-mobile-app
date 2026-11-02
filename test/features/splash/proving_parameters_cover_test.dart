import 'dart:async';

import 'package:crypto_mobile_app/core/bootstrap/proving_parameters_preparation.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:crypto_mobile_app/features/splash/widgets/proving_parameters_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(LaunchCoverClock.reset);

  Widget app(ProvingParametersPreparation preparation, {Widget? child}) =>
      MaterialApp(
        theme: ThemeData(extensions: DesignSystemTheme.standardExtensions()),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProvingParametersCover(
          preparation: preparation,
          child: child ?? const Scaffold(body: Text('Application content')),
        ),
      );

  testWidgets('shows progress only while preparation is active',
      (tester) async {
    final preparation = ProvingParametersPreparation();
    addTearDown(preparation.dispose);
    final finish = Completer<void>();
    await tester.pumpWidget(app(preparation));
    expect(find.byType(LaunchCover), findsNothing);
    final pending = preparation.run((report) async {
      report(5, 10);
      await finish.future;
    });
    await tester.pump();
    expect(find.byType(LaunchCover), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .5);
    final context = tester.element(find.byType(ProvingParametersCover));
    expect(
        find.text(
            AppLocalizations.of(context).provingParametersDownloadProgress(50)),
        findsOneWidget);
    finish.complete();
    await pending;
    await tester.pump();
    expect(find.byType(LaunchCover), findsNothing);
    expect(find.text('Application content'), findsOneWidget);
  });

  testWidgets('shows an indeterminate download before a total is known',
      (tester) async {
    final preparation = ProvingParametersPreparation();
    addTearDown(preparation.dispose);
    final finish = Completer<void>();
    await tester.pumpWidget(app(preparation));
    final pending = preparation.run((_) => finish.future);
    await tester.pump();
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        isNull);
    finish.complete();
    await pending;
    await tester.pump();
  });

  testWidgets('retry resumes the same operation and restores the child',
      (tester) async {
    final preparation = ProvingParametersPreparation();
    addTearDown(preparation.dispose);
    final finish = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(app(preparation));
    final pending = preparation.run((report) async {
      attempts++;
      report(2, 10);
      if (attempts == 1) throw StateError('offline');
      await finish.future;
    });
    await tester.pump();
    expect(preparation.value!.failed, isTrue);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final context = tester.element(find.byType(ProvingParametersCover));
    expect(
        find.text(AppLocalizations.of(context).provingParametersDownloadFailed),
        findsOneWidget);
    expect(find.widgetWithText(Button, AppLocalizations.of(context).retry),
        findsOneWidget);
    await tester.tap(find.byType(Button));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(Button), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    finish.complete();
    await pending;
    await tester.pump();
    expect(find.byType(LaunchCover), findsNothing);
  });

  testWidgets('the preparation cover blocks underlying controls',
      (tester) async {
    final preparation = ProvingParametersPreparation();
    addTearDown(preparation.dispose);
    final finish = Completer<void>();
    var taps = 0;
    await tester.pumpWidget(app(preparation,
        child: Scaffold(
            body: Align(
          alignment: Alignment.topLeft,
          child:
              TextButton(onPressed: () => taps++, child: const Text('Sign in')),
        ))));
    final buttonCenter = tester.getCenter(find.text('Sign in'));
    final pending = preparation.run((_) => finish.future);
    await tester.pump();
    await tester.tapAt(buttonCenter);
    expect(taps, 0);
    finish.complete();
    await pending;
    await tester.pump();
    await tester.tapAt(buttonCenter);
    expect(taps, 1);
  });
}
