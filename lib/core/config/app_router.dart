import 'package:flutter/material.dart';

class AppRoutes {
  // Core routes. Login/onboarding is platform-owned (SV web) — the app has
  // no native auth or onboarding routes; splash goes straight to home, which
  // is the full-bleed SV shell. Everything else is native-only tooling
  // (diagnostics, benchmark, zk-identity hardware flows) or the dapp browser.
  static const splash = '/splash';
  static const home = '/home';
  static const homeSlash = '/';

  static const dapps = '/dapps';
  static const dappDetail = '/dapps/:slug';
  static const dappPinned = '/dapps/pinned/:id';

  // Native diagnostics tooling.
  static const diagnostics = '/settings/diagnostics';
  static const deviceBenchmark = '/settings/device-benchmark';
  static const deviceBenchmarkRun = '/settings/device-benchmark/run';
  static const deviceBenchmarkResultDetail =
      '/settings/device-benchmark/result';
  static const httpDebugLogs = '/settings/http-debug-logs';

  // Native wallet trust surface opened by the SV Wallet sheet.
  static const walletStaking = '/wallet/staking';

  static String dappPinnedFor(String id) => '/dapps/pinned/$id';

  // ZK Identity (native: runs NFC/hardware flows)
  static const zkIdentityDetail = '/challenges/zk-identity';
  static const zkIdentityFlow = '/challenges/zk-identity/flow';
}

/// The SV-shell location a pinned homescreen tile opens.
///
/// [route] is the platform hash route recorded at pin time
/// (`PinnedDapp.route`, e.g. `app/<slug>`). Folding it into
/// `/home?sv=<route>` reuses the same shell — and, when the app is warm, the
/// same *running* webview — that every other surface uses.
///
/// There is deliberately no "this pin isn't ours" answer. Pinning is gated on
/// a privileged bridge lease that requires the platform origin, so every tile
/// is a platform tile by construction; the origin was settled when the tile
/// was created and is not re-litigated here. An empty route means the tile
/// addresses the platform root.
String svShellRouteForPinnedRoute(String route) {
  final target = route.trim();
  if (target.isEmpty) return AppRoutes.home;
  return '${AppRoutes.home}?sv=${Uri.encodeQueryComponent(target)}';
}

// Inert navigation handle used by notification and clock-warning UI. Session
// ingress is deliberately not stored in this public library.
final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mainNavigator');

/// Getter to expose the navigator key for external navigation
/// This is used by the notification tap handler to navigate from outside the widget tree
GlobalKey<NavigatorState> get appNavigatorKey => _navigatorKey;
