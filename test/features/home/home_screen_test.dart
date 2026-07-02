import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

void main() {
  const debugPages = [
    SizedBox(key: Key('challenges-page')),
    SizedBox(key: Key('wallet-page')),
    SizedBox(key: Key('dapps-page')),
    SizedBox(key: Key('node-page')),
    SizedBox(key: Key('settings-page')),
  ];

  Widget app({int initialTab = HomeTab.challenges}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
        home: HomeScreen(
          initialTab: initialTab,
          debugPages: debugPages,
        ),
      ),
    );
  }

  testWidgets('bottom nav centers dApps between Challenges and Wallet',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    final challengesCenter = tester.getCenter(find.text('Challenges'));
    final dappsCenter = tester.getCenter(find.text('dApps'));
    final walletCenter = tester.getCenter(find.text('Wallet'));

    expect(challengesCenter.dx, lessThan(dappsCenter.dx));
    expect(dappsCenter.dx, lessThan(walletCenter.dx));
  });

  testWidgets('tapping center dApps selects the dApps tab', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('dApps'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(currentHomeTabProvider), HomeTab.dapps);
  });

  testWidgets('initial dApps tab selects the center nav item', (tester) async {
    await tester.pumpWidget(app(initialTab: HomeTab.dapps));
    await tester.pump();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });
}
