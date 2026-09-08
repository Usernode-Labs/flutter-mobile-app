part of 'package:crypto_mobile_app/main.dart';

final _routerLog = LoggingService.instance.withTag('usernode/Router');
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

/// Builds the sole router under the private process composition root.
///
/// The mutable Social ingress never enters Riverpod and is captured only by
/// these private route-builder closures. Features receive the read-only
/// projection and exact-session runner surface selected by those closures.
GoRouter _createAppRouter(
  WidgetRef ref,
  _NativeSessionRuntime nativeSession,
) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    observers: SentryUtil.navigatorObservers(),
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeSlash,
        builder: (context, state) => SvShellScreen(
          initialHash: state.uri.queryParameters['sv'],
          navigationRequest: state.uri.queryParameters['launch'],
          nativeSessionBridge: nativeSession.bridge,
          sessionAccess: nativeSession.sessions,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => SvShellScreen(
          initialHash: state.uri.queryParameters['sv'],
          navigationRequest: state.uri.queryParameters['launch'],
          nativeSessionBridge: nativeSession.bridge,
          sessionAccess: nativeSession.sessions,
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
        builder: (context, state) => StakingDelegationScreen(
          session: nativeSession.sessions.current,
        ),
      ),
      GoRoute(
        path: AppRoutes.zkIdentityDetail,
        // Temporary Social CTA compatibility path. Flutter owns only the
        // retained device-proof mechanics, never challenge/reward product UI.
        builder: (context, state) => ZkIdentityFlowScreen(
          session: nativeSession.sessions.current,
        ),
      ),
      GoRoute(
        path: AppRoutes.zkIdentityFlow,
        builder: (context, state) => ZkIdentityFlowScreen(
          session: nativeSession.sessions.current,
        ),
      ),
      GoRoute(
        path: AppRoutes.dapps,
        redirect: (context, state) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.dappPinned,
        // Homescreen tiles always fold into the shell: the route they open was
        // recorded when the tile was created, at which point the privileged
        // bridge lease had already proven the pinning page was on the platform
        // origin. There is no browser fallback left to dead-end in — a tile
        // whose id no longer resolves lands on the shell root instead.
        redirect: (context, state) async {
          final id = state.pathParameters['id'];
          if (id == null) return AppRoutes.home;
          try {
            final dapps = await ref.read(pinnedDappsProvider.future);
            final dapp = dapps.where((d) => d.id == id).firstOrNull;
            if (dapp == null) {
              _routerLog.warn('Pinned dapp $id is no longer in the registry');
              return AppRoutes.home;
            }
            return _withPinnedLaunchRevision(
              svShellRouteForPinnedRoute(dapp.route),
            );
          } catch (error) {
            _routerLog.warn('Pinned dapp launch failed to resolve: $error');
            return AppRoutes.home;
          }
        },
      ),
      GoRoute(
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
      if (shouldBlockUsernodeDeepLink(state.uri)) {
        _routerLog.warn('Blocked unsupported app deep link: ${state.uri}');
        return AppRoutes.home;
      }
      if (state.matchedLocation == AppRoutes.splash) {
        return AppRoutes.home;
      }
      return null;
    },
  );
}
