import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';

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

/// Remaps a pinned dapp's URL into the SV-shell home route when the URL
/// lives on the trusted SV origin, or returns null when it should open in
/// the standalone dapp browser instead.
///
/// SV pins its apps as `https://<sv-origin>/#app/<slug>` — a hash route of
/// the platform SPA. Opening that in the standalone browser shows the
/// pre-thin-shell UI (native app bar over a second SV boot). Folding it
/// into `/home?sv=<fragment>` reuses the same shell (and, when the app is
/// warm, the same *running* webview) that every other surface uses.
/// Non-SV origins keep the standalone browser: that's what it's for.
String? svShellRouteForPinnedDappUrl({
  required String pinnedUrl,
  required String dappsTabUrl,
}) {
  final pinned = Uri.tryParse(pinnedUrl.trim());
  final trusted = Uri.tryParse(dappsTabUrl.trim());
  if (pinned == null || trusted == null) return null;
  if (pinned.host.isEmpty || trusted.host.isEmpty) return null;
  if (!isSameWebOrigin(pinned, trusted)) {
    return null;
  }
  // The SV remap is a fragment-router optimization, not a general URL
  // rewrite. Preserve path/query-routed pins by opening their exact URL in
  // the standalone fallback instead of silently sending them to shell home.
  final pinnedPath = pinned.path.isEmpty ? '/' : pinned.path;
  final trustedPath = trusted.path.isEmpty ? '/' : trusted.path;
  if (pinnedPath != trustedPath || pinned.query != trusted.query) return null;
  final fragment = pinned.fragment;
  if (fragment.isEmpty) return AppRoutes.home;
  return '${AppRoutes.home}?sv=${Uri.encodeQueryComponent(fragment)}';
}

// Inert navigation handle used by notification and clock-warning UI. Session
// ingress is deliberately not stored in this public library.
final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mainNavigator');

/// Getter to expose the navigator key for external navigation
/// This is used by the notification tap handler to navigate from outside the widget tree
GlobalKey<NavigatorState> get appNavigatorKey => _navigatorKey;
