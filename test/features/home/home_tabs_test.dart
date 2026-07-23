import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/auth/data/models/me.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';

void main() {
  group('visibleTabsFor', () {
    test('guest and member see Challenges, dApps and More — no Wallet', () {
      for (final level in [UserLevel.guest, UserLevel.member]) {
        expect(
          visibleTabsFor(level),
          [HomeTab.challenges, HomeTab.dapps, HomeTab.more],
          reason: level.name,
        );
      }
    });

    test('operator additionally sees Wallet', () {
      expect(
        visibleTabsFor(UserLevel.operator),
        [HomeTab.challenges, HomeTab.dapps, HomeTab.wallet, HomeTab.more],
      );
    });

    // Wallet is the only tier-gated tab; everything else is always present so
    // the nav does not reshuffle underneath the user as /me resolves.
    test('only Wallet differs between tiers', () {
      final member = visibleTabsFor(UserLevel.member).toSet();
      final operator = visibleTabsFor(UserLevel.operator).toSet();
      expect(operator.difference(member), {HomeTab.wallet});
      expect(member.difference(operator), isEmpty);
    });

    test('More is always last', () {
      for (final level in UserLevel.values) {
        expect(visibleTabsFor(level).last, HomeTab.more, reason: level.name);
      }
    });
  });

  group('defaultTabFor', () {
    test('operator lands on Challenges', () {
      expect(defaultTabFor(UserLevel.operator), HomeTab.challenges);
    });

    test('guest and member land on dApps', () {
      expect(defaultTabFor(UserLevel.guest), HomeTab.dapps);
      expect(defaultTabFor(UserLevel.member), HomeTab.dapps);
    });

    test('the default tab is always visible for that tier', () {
      for (final level in UserLevel.values) {
        expect(visibleTabsFor(level), contains(defaultTabFor(level)),
            reason: level.name);
      }
    });
  });

  group('resolveVisibleTab', () {
    test('keeps a tab that is visible for the tier', () {
      expect(resolveVisibleTab(HomeTab.dapps, UserLevel.guest), HomeTab.dapps);
      expect(resolveVisibleTab(HomeTab.wallet, UserLevel.operator),
          HomeTab.wallet);
    });

    // An operator sitting on Wallet who is downgraded (or signs out to guest)
    // must not be left on a tab that no longer exists.
    test('falls back to the tier default when the tab is not visible', () {
      expect(resolveVisibleTab(HomeTab.wallet, UserLevel.guest), HomeTab.dapps);
      expect(
          resolveVisibleTab(HomeTab.wallet, UserLevel.member), HomeTab.dapps);
    });

    // Settings and Node Status live behind More rather than in the nav bar.
    // They are legitimate destinations and must not be bounced away.
    test('keeps More-reachable destinations for every tier', () {
      for (final level in UserLevel.values) {
        for (final tab in [HomeTab.settings, HomeTab.nodeStatus]) {
          expect(resolveVisibleTab(tab, level), tab, reason: '$level/$tab');
        }
      }
    });
  });

  // home_screen.dart keeps a const page count for its constructor assert.
  // Adding a HomeTab without adding its page must fail here rather than
  // silently render the wrong screen.
  test('HomeTab has exactly the number of pages home_screen expects', () {
    expect(HomeTab.values.length, 6);
  });
}
