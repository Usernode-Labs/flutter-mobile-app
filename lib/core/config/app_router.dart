import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/diagnostics_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_detail_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_flow_screen.dart';
import 'package:crypto_mobile_app/features/dapps/sv_shell_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_url.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_result_detail_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_run_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/http_debug_logs_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/staking_delegation_screen.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/Router');

class AppRoutes {
  // Core routes. Login/onboarding is platform-owned (SV web) — the app has
  // no native auth or onboarding routes; splash goes straight to home, which
  // is the full-bleed SV shell. Everything else is native-only tooling
  // (diagnostics, benchmark, zk-identity hardware flows) or the dapp browser.
  static const splash = '/splash';
  static const home = '/home';
  static const homeSlash = '/';

  // Challenge deep-link remap target (native leaderboard retired into SV).
  static const leaderboard = '/challenges/leaderboard';

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

// Create a stable navigator key outside the provider
final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mainNavigator');
int _pinnedLaunchRevision = 0;

String _withPinnedLaunchRevision(String route) {
  final uri = Uri.parse(route);
  return uri.replace(
    queryParameters: {
      ...uri.queryParameters,
      'launch': (++_pinnedLaunchRevision).toString(),
    },
  ).toString();
}

/// Getter to expose the navigator key for external navigation
/// This is used by the notification tap handler to navigate from outside the widget tree
GlobalKey<NavigatorState> get appNavigatorKey => _navigatorKey;

final appRouterProvider = Provider<GoRouter>((ref) {
  // Do NOT ref.watch state providers here: a watch rebuilds this provider
  // when they change (e.g. loading -> data right after launch), which
  // creates a brand-new GoRouter and resets navigation to /splash — this
  // stomped cold-start deep links from homescreen widgets. The listen keeps
  // the leaderboard bootstrap chain alive (it hydrates the season context
  // the zk-identity challenge providers read) without triggering rebuilds.
  ref.listen(leaderboardBootstrapProvider, (_, __) {});

  return GoRouter(
    navigatorKey: _navigatorKey,
    observers: SentryUtil.navigatorObservers(),
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeSlash,
        // Home is the full-bleed SV webview (app-as-SV-chrome). `?sv=<hash>`
        // carries a target SV hash route for deep-link remaps (e.g.
        // /home?sv=challenges from usernode://app/challenges links).
        builder: (context, state) => SvShellScreen(
          initialHash: state.uri.queryParameters['sv'],
          navigationRequest: state.uri.queryParameters['launch'],
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => SvShellScreen(
          initialHash: state.uri.queryParameters['sv'],
          navigationRequest: state.uri.queryParameters['launch'],
        ),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (context, state) => const DiagnosticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceBenchmark,
        builder: (context, state) => const DeviceBenchmarkScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceBenchmarkRun,
        builder: (context, state) => const DeviceBenchmarkRunScreen(),
      ),
      GoRoute(
        path: AppRoutes.deviceBenchmarkResultDetail,
        builder: (context, state) {
          final extra = state.extra as DeviceBenchmarkResultDetailArgs;
          return DeviceBenchmarkResultDetailScreen(args: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.httpDebugLogs,
        builder: (context, state) => const HttpDebugLogsScreen(),
      ),
      GoRoute(
        path: AppRoutes.walletStaking,
        builder: (context, state) => const StakingDelegationScreen(),
      ),
      GoRoute(
        path: AppRoutes.zkIdentityDetail,
        builder: (context, state) => const ZkIdentityDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.zkIdentityFlow,
        builder: (context, state) => const ZkIdentityFlowScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        // usernode://app/challenges/leaderboard remaps to SV's challenges hash
        // route — the native leaderboard is retired inside the SV shell.
        // ZK-identity routes stay native — they run hardware flows.
        redirect: (context, state) => '${AppRoutes.home}?sv=challenges',
      ),
      GoRoute(
        path: AppRoutes.dapps,
        // SV *is* the dapps home, so this route folds into the shell. Kept as a
        // redirect (not deleted): it's in the deep-link allowlist and the
        // dapp-browser Home button points here.
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        // Registered before dappDetail for clarity; no actual overlap since
        // this path has an extra segment (`/dapps/pinned/<id>` vs
        // `/dapps/<slug>`).
        path: AppRoutes.dappPinned,
        // Widget tiles / launcher shortcuts deep-link here. Trusted SV
        // fragment pins remap into the warm shell; legacy/non-SV and
        // path/query-routed pins retain the standalone webview fallback.
        redirect: (context, state) async {
          final id = state.pathParameters['id'];
          if (id == null) return AppRoutes.home;
          try {
            final dapps = await ref.read(pinnedDappsProvider.future);
            final dapp = dapps.where((d) => d.id == id).firstOrNull;
            if (dapp == null) return AppRoutes.home;
            final shellRoute = svShellRouteForPinnedDappUrl(
              pinnedUrl: dapp.url,
              dappsTabUrl: AppConfig.dappsTabUrl,
            );
            if (shellRoute == null) return null;
            // A distinct final location makes a repeat tap observable even
            // when it targets the same pin as the previous launch.
            return _withPinnedLaunchRevision(shellRoute);
          } catch (e) {
            _log.warn('Pinned dapp shell remap failed: $e');
            return AppRoutes.home;
          }
        },
        builder: (context, state) =>
            _PinnedDappFallbackScreen(id: state.pathParameters['id']),
      ),
      GoRoute(
        // Legacy `usernode://app/dapps/<slug>` deep links. Nothing mints
        // these anymore (the native dapps list and backend CTA dispatcher
        // are retired), but the allowlist still admits them — hand the
        // slug to the SV shell's own `#app/<slug>` route, which owns
        // not-found handling for slugs it doesn't know.
        path: AppRoutes.dappDetail,
        redirect: (context, state) {
          final slug = state.pathParameters['slug'];
          if (slug == null || slug.isEmpty) return AppRoutes.home;
          final fragment = Uri.encodeQueryComponent('app/$slug');
          return '${AppRoutes.home}?sv=$fragment';
        },
      ),
    ],
    redirect: (context, state) {
      final currentLocation = state.matchedLocation;
      final requestUri = state.uri;

      // Login/onboarding is platform-owned: the SV shell renders the login
      // page itself when the web session is missing, and drives the native
      // identity over bridge v4 (completeLogin/startNode). The router no
      // longer gates on auth status — wallet signing goes through the native
      // confirm sheet, which enforces its own identity gates.

      if (shouldBlockUsernodeDeepLink(requestUri)) {
        _log.warn('Blocked unsupported app deep link: $requestUri');
        return AppRoutes.home;
      }

      // Splash is a transient boot route — land in the SV shell.
      if (currentLocation == AppRoutes.splash) {
        return AppRoutes.home;
      }

      return null;
    },
  );
});

class _PinnedDappFallbackScreen extends ConsumerWidget {
  const _PinnedDappFallbackScreen({required this.id});

  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(pinnedDappsProvider).when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, __) => const SizedBox.shrink(),
          data: (dapps) {
            final dapp = dapps.where((d) => d.id == id).firstOrNull;
            if (dapp == null) return const SizedBox.shrink();
            final dappUri = Uri.tryParse(dapp.url);
            final svUri = Uri.tryParse(AppConfig.dappsTabUrl);
            final usesAppBoundOrigin = dappUri != null &&
                svUri != null &&
                isSameWebOrigin(dappUri, svUri);
            return DappWebViewScreen(
              key: ValueKey('pinned:${dapp.url}'),
              url: dapp.url,
              name: dapp.name,
              appBoundDomainsOnly: usesAppBoundOrigin,
              standalone: true,
            );
          },
        );
  }
}
