import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/diagnostics_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_detail_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_flow_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/dapps/sv_shell_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_result_detail_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_run_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/http_debug_logs_screen.dart';
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

  static String dappDetailFor(String slug) => '/dapps/$slug';
  static String dappPinnedFor(String id) => '/dapps/pinned/$id';

  // ZK Identity (native: runs NFC/hardware flows)
  static const zkIdentityDetail = '/challenges/zk-identity';
  static const zkIdentityFlow = '/challenges/zk-identity/flow';
}

// Create a stable navigator key outside the provider
final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mainNavigator');

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
        builder: (context, state) =>
            SvShellScreen(initialHash: state.uri.queryParameters['sv']),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            SvShellScreen(initialHash: state.uri.queryParameters['sv']),
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
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return Consumer(
            builder: (context, ref, _) {
              final pinnedAsync = ref.watch(pinnedDappsProvider);
              return pinnedAsync.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Scaffold(
                  appBar: AppBar(),
                  body: Center(
                    child: Text('Failed to load pinned dApp: $error'),
                  ),
                ),
                data: (_) {
                  final dapp =
                      id == null ? null : ref.watch(pinnedDappByIdProvider(id));
                  if (dapp == null) {
                    return Scaffold(
                      appBar: AppBar(),
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('dApp not found'),
                            Button(
                              label: 'Back',
                              size: ButtonSize.small,
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(AppRoutes.home);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Keyed by URL: navigating pinned dapp A -> pinned dapp
                  // B reuses this same route with a new param, and without
                  // a key the old webview state (still showing A) is kept.
                  return DappWebViewScreen(
                    key: ValueKey('pinned:${dapp.url}'),
                    url: dapp.url,
                    name: dapp.name,
                  );
                },
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.dappDetail,
        builder: (context, state) {
          final slug = state.pathParameters['slug'];
          return Consumer(
            builder: (context, ref, _) {
              final dappsAsync = ref.watch(dappsProvider);
              return dappsAsync.when(
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Scaffold(
                  appBar: AppBar(),
                  body: Center(
                    child: Text('Failed to load dApp: $error'),
                  ),
                ),
                data: (_) {
                  final dapp =
                      slug == null ? null : ref.watch(dappBySlugProvider(slug));
                  if (dapp == null) {
                    return Scaffold(
                      appBar: AppBar(),
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('dApp not found'),
                            Button(
                              label: 'Back',
                              size: ButtonSize.small,
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(AppRoutes.home);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Keyed for the same reason as the pinned route above:
                  // switching between dapp slugs must rebuild the webview.
                  return DappWebViewScreen(
                    key: ValueKey('dapp:${dapp.url}'),
                    url: dapp.url,
                    name: dapp.name,
                  );
                },
              );
            },
          );
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
