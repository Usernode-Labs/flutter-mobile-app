import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/use_demo_accounts_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/import_api_account_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/welcome_claim_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/onboarding_import_api_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission1_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission2_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission3_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/new_ux_home_shell.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/slot_assignments_screen.dart';
import 'package:crypto_mobile_app/core/main_app.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/block_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/slot_production_stats_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/features/rewards/screens/rewards_breakdown_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag(LogTag.router);

class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding/welcome';
  static const home = '/home';
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
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeClaimScreen(),
      ),
      GoRoute(
        path: '/onboarding/import-api',
        builder: (context, state) => const NewUxOnboardingImportApiScreen(),
      ),
      GoRoute(
        path: '/onboarding/permission1',
        builder: (context, state) => const Permission1Screen(),
      ),
      GoRoute(
        path: '/onboarding/permission2',
        builder: (context, state) => const Permission2Screen(),
      ),
      GoRoute(
        path: '/onboarding/permission3',
        builder: (context, state) => const Permission3Screen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const NewUxHomeShell(),
      ),
      GoRoute(
        path: '/produced/slot-assignments',
        builder: (context, state) => const SlotAssignmentsScreen(),
      ),
      GoRoute(
        path: '/import-api-account',
        builder: (context, state) => const ImportApiAccountScreen(),
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
        if (currentLocation.startsWith('/onboarding/') ||
            currentLocation == '/import-api-account' ||
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

      // Allow onboarding flow routes
      if (currentLocation == '/import-api-account' ||
          currentLocation == '/use-demo-accounts') {
        LoggingService.instance.trace('Allowing onboarding flow route');
        return null;
      }

      // Redirect from splash and onboarding to home if user already has an account
      if (currentLocation == AppRoutes.splash ||
          currentLocation.startsWith('/onboarding/')) {
        LoggingService.instance
            .trace('Redirecting $currentLocation to /home');
        return AppRoutes.home;
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
