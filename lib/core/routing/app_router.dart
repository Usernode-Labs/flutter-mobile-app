import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/account_mode_selection_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/use_demo_accounts_screen.dart';
import 'package:crypto_mobile_app/core/main_app.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/block_details_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/slot_production_stats_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/screens/rewards_breakdown_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag(LogTag.router);

class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const main = '/main';
}

/// A ChangeNotifier that listens to Riverpod provider changes and notifies GoRouter
/// This bridges Riverpod's state management with GoRouter's refresh mechanism
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this._ref) {
    // Listen to hasAnyAccountProvider changes
    _ref.listen<AsyncValue<bool>>(
      hasAnyAccountProvider,
      (previous, next) {
        // Notify GoRouter to re-run its redirect logic when account state changes
        notifyListeners();
      },
    );
  }

  final Ref _ref;

  @override
  void dispose() {
    // Clean up listener
    super.dispose();
  }
}

// Create a stable navigator key outside the provider
final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'mainNavigator');

/// Getter to expose the navigator key for external navigation
/// This is used by the notification tap handler to navigate from outside the widget tree
GlobalKey<NavigatorState> get appNavigatorKey => _navigatorKey;

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watch the provider to make router reactive
  ref.watch(hasAnyAccountProvider);

  return GoRouter(
    navigatorKey: _navigatorKey,
    observers: SentryUtil.navigatorObservers(),
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(ref),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const AccountModeSelectionScreen(),
      ),
      GoRoute(
        path: '/use-demo-accounts',
        builder: (context, state) => const UseDemoAccountsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/background-production-settings',
        builder: (context, state) => const BackgroundProductionSettingsScreen(),
      ),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsBreakdownScreen(),
      ),
      // Redirect bare /main to default tab
      GoRoute(
        path: AppRoutes.main,
        redirect: (context, state) => '/main/node',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainApp(currentLocation: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/main/node',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const NodeStatusScreen(),
            ),
          ),
          GoRoute(
            path: '/main/node/won-slots',
            builder: (context, state) => const NodeWonSlotsScreen(),
          ),
          GoRoute(
            path: '/main/node/produced-blocks',
            builder: (context, state) => const ProducedBlocksScreen(),
          ),
          GoRoute(
            path: '/main/node/production-stats',
            builder: (context, state) => const SlotProductionStatsScreen(),
          ),
          GoRoute(
            path: '/main/node/block-details',
            builder: (context, state) {
              final block = state.extra as RpcStatusBlockInfo;
              return BlockDetailsScreen(block: block);
            },
          ),
          GoRoute(
            path: '/main/node/mempool',
            builder: (context, state) => const MempoolDetailsScreen(),
          ),
          GoRoute(
            path: '/main/settings',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const BackgroundProductionSettingsScreen(),
            ),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final hasAny = ref
          .read(hasAnyAccountProvider)
          .maybeWhen(data: (v) => v, orElse: () => null);

      final currentLocation = state.matchedLocation;

      _log.trace(
          'Redirect guard called - location: $currentLocation, hasAny: $hasAny');

      // Still loading account state
      if (hasAny == null) {
        _log.trace('Account state loading - allowing navigation');
        return null;
      }

      // Define public routes that don't require an account
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
      ];

      final isPublicRoute = publicRoutes.contains(currentLocation);
      _log.trace(
          'Route $currentLocation is ${isPublicRoute ? "public" : "private"}');

      // No account exists
      if (!hasAny) {
        _log.trace('No account exists');
        // Splash should redirect to onboarding (transient route)
        if (currentLocation == AppRoutes.splash) {
          LoggingService.instance.trace('Redirecting splash to onboarding');
          return AppRoutes.onboarding;
        }
        // Allow onboarding and demo accounts routes
        if (currentLocation == AppRoutes.onboarding ||
            currentLocation == '/use-demo-accounts') {
          LoggingService.instance.trace('Allowing onboarding route');
          return null;
        }
        // Redirect all other routes to onboarding
        LoggingService.instance
            .trace('Redirecting private route to onboarding');
        return AppRoutes.onboarding;
      }

      // Account exists
      _log.trace('Account exists');

      // Allow demo accounts route during onboarding flow
      if (currentLocation == '/use-demo-accounts') {
        LoggingService.instance.trace('Allowing onboarding flow route');
        return null;
      }

      // Redirect from splash and onboarding to node if user already has an account
      if (currentLocation == AppRoutes.splash ||
          currentLocation == AppRoutes.onboarding) {
        LoggingService.instance
            .trace('Redirecting $currentLocation to /main/node');
        return '/main/node';
      }

      // Allow all other routes when account exists
      LoggingService.instance.trace('Allowing route: $currentLocation');
      return null;
    },
  );
});

/// Helper function to build pages with subtle fade transitions
Page<dynamic> _buildPageWithFade(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Curves.easeInOut)),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 150),
  );
}
