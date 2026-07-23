import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

/// Pages hosted by the HomeScreen `IndexedStack`.
///
/// Declaration order **is** the stack order — see `_homePages` in
/// `home_screen.dart`. This used to be a set of `int` constants indexing a const
/// list, which meant hiding a page silently shifted every later one.
///
/// Not every tab appears in the bottom nav: [settings] and [nodeStatus] are
/// reached through [more], and [wallet] exists only for operators.
enum HomeTab { challenges, wallet, dapps, nodeStatus, settings, more }

/// Bottom-nav destinations for [level], in display order.
///
/// Wallet is the only tier-gated entry: a guest has no on-chain account and a
/// member has not become an operator yet, so there is nothing to show. Keeping
/// every other destination constant means the nav does not reshuffle underneath
/// the user while `/me` resolves.
List<HomeTab> visibleTabsFor(UserLevel level) => [
      HomeTab.challenges,
      HomeTab.dapps,
      if (level == UserLevel.operator) HomeTab.wallet,
      HomeTab.more,
    ];

/// Where [level] lands on entering the app shell.
///
/// Operators run a node and are here for Challenges. Guests and members get
/// dApps, which is the part of the app that works fully for them — their
/// Challenges tab is a sign-in or waiting-list prompt.
HomeTab defaultTabFor(UserLevel level) =>
    level == UserLevel.operator ? HomeTab.challenges : HomeTab.dapps;

/// Coerces [tab] to something [level] is allowed to be on.
///
/// Guards the downgrade case: an operator sitting on Wallet who signs out to
/// guest, or whom `/me` demotes, must not be left on a tab that is no longer in
/// their nav. [HomeTab.settings] and [HomeTab.nodeStatus] are legitimate
/// More-reachable destinations for every tier and are left alone.
HomeTab resolveVisibleTab(HomeTab tab, UserLevel level) {
  const reachableOutsideNav = {HomeTab.settings, HomeTab.nodeStatus};
  if (reachableOutsideNav.contains(tab)) return tab;
  return visibleTabsFor(level).contains(tab) ? tab : defaultTabFor(level);
}

/// Tracks the currently selected tab in the HomeScreen's navigation bar.
final currentHomeTabProvider =
    StateProvider<HomeTab>((ref) => HomeTab.challenges);
