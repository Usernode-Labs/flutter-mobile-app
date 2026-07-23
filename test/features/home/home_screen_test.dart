import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/home/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

void main() {
  // Order must match HomeTab.
  const debugPages = [
    SizedBox(key: Key('challenges-page')),
    SizedBox(key: Key('wallet-page')),
    SizedBox(key: Key('dapps-page')),
    SizedBox(key: Key('node-page')),
    SizedBox(key: Key('settings-page')),
    SizedBox(key: Key('more-page')),
  ];

  Widget app({
    HomeTab? initialTab,
    UserLevel level = UserLevel.operator,
    bool debug = true,
  }) {
    return ProviderScope(
      overrides: [userLevelProvider.overrideWithValue(level)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: themeWithExtensions(),
        home: HomeScreen(
          initialTab: initialTab,
          debugPages: debug ? debugPages : null,
        ),
      ),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

  group('operator', () {
    testWidgets('sees Challenges, dApps, Wallet and More in order',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();

      final xs = [
        for (final label in ['Challenges', 'dApps', 'Wallet', 'More'])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(xs, orderedEquals([...xs]..sort()));
    });

    testWidgets('lands on Challenges by default', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      expect(
          containerOf(tester).read(currentHomeTabProvider), HomeTab.challenges);
    });
  });

  group('guest and member', () {
    testWidgets('do not see a Wallet tab', (tester) async {
      for (final level in [UserLevel.guest, UserLevel.member]) {
        await tester.pumpWidget(app(level: level));
        await tester.pump();

        expect(find.text('Wallet'), findsNothing, reason: level.name);
        expect(find.text('Challenges'), findsOneWidget, reason: level.name);
        expect(find.text('dApps'), findsOneWidget, reason: level.name);
        expect(find.text('More'), findsOneWidget, reason: level.name);
      }
    });

    testWidgets('land on dApps by default', (tester) async {
      for (final level in [UserLevel.guest, UserLevel.member]) {
        await tester.pumpWidget(app(level: level));
        await tester.pump();
        expect(containerOf(tester).read(currentHomeTabProvider), HomeTab.dapps,
            reason: level.name);
      }
    });

    // The IndexedStack is indexed by HomeTab.index, so hiding Wallet must not
    // shift dApps — the bug the old int-constant list was prone to.
    testWidgets('dApps tab still shows the dApps page', (tester) async {
      await tester.pumpWidget(app(level: UserLevel.guest));
      await tester.pump();

      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.index, HomeTab.dapps.index);
    });
  });

  testWidgets('tapping a nav item selects that tab', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('dApps'));
    await tester.pump();

    expect(containerOf(tester).read(currentHomeTabProvider), HomeTab.dapps);
  });

  testWidgets('More is selected and shows the More page', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('More'));
    await tester.pump();

    expect(containerOf(tester).read(currentHomeTabProvider), HomeTab.more);
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, HomeTab.more.index);
  });

  testWidgets('initialTab overrides the tier default', (tester) async {
    await tester.pumpWidget(app(initialTab: HomeTab.dapps));
    await tester.pump();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 1);
  });

  // Settings and Node Status are reached through More, so they are not nav
  // destinations — but sitting on one must not crash or reset the nav.
  testWidgets('More stays highlighted on a More-reachable page',
      (tester) async {
    await tester.pumpWidget(app(initialTab: HomeTab.settings));
    await tester.pump();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 3, reason: 'More is the 4th operator tab');
    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, HomeTab.settings.index);
  });

  // A demoted operator must not be stranded on a tab their tier no longer has.
  testWidgets('a guest parked on Wallet falls back to dApps', (tester) async {
    await tester
        .pumpWidget(app(initialTab: HomeTab.wallet, level: UserLevel.guest));
    await tester.pump();

    final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.index, HomeTab.dapps.index);
    expect(find.text('Wallet'), findsNothing);
  });

  // "Hide Wallet" must mean inactive, not merely absent from the nav:
  // IndexedStack builds every child, so a real WalletScreen would keep its
  // refresh timer and balance reads running for a tier with no account.
  group('wallet page gating', () {
    test('operator gets the real WalletScreen', () {
      expect(homePagesFor(UserLevel.operator)[HomeTab.wallet.index],
          isA<WalletScreen>());
    });

    test('guest and member get a placeholder, not WalletScreen', () {
      for (final level in [UserLevel.guest, UserLevel.member]) {
        expect(homePagesFor(level)[HomeTab.wallet.index],
            isNot(isA<WalletScreen>()),
            reason: level.name);
      }
    });

    // Wallet and Challenges are the only tier-varying pages: Wallet becomes a
    // placeholder, Challenges becomes the gate screen. Everything else must be
    // identical, so a tier change cannot quietly swap an unrelated screen.
    test('only wallet and challenges vary across tiers', () {
      final operator = homePagesFor(UserLevel.operator);
      final guest = homePagesFor(UserLevel.guest);
      const tierVarying = {HomeTab.wallet, HomeTab.challenges};
      for (final tab in HomeTab.values) {
        final same =
            guest[tab.index].runtimeType == operator[tab.index].runtimeType;
        expect(same, !tierVarying.contains(tab), reason: tab.name);
      }
    });

    test('page list length matches HomeTab', () {
      expect(homePagesFor(UserLevel.guest).length, HomeTab.values.length);
    });
  });

  // The coercion must be written back, not just rendered — screens listen to
  // the raw provider to decide whether they are active.
  testWidgets('a coerced tab is synced back into the provider', (tester) async {
    await tester
        .pumpWidget(app(initialTab: HomeTab.wallet, level: UserLevel.guest));
    await tester.pump();
    await tester.pump();

    expect(containerOf(tester).read(currentHomeTabProvider), HomeTab.dapps);
  });
}
