import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/welcome_claim_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/onboarding_import_api_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission1_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission2_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/permission3_screen.dart';
import 'package:crypto_mobile_app/features/home/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/slot_assignments_screen.dart';
import 'package:crypto_mobile_app/core/main_app.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/block_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/slot_production_stats_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag(LogTag.router);

class AppRoutes {
  // Core routes
  static const splash = '/splash';
  static const onboarding = '/onboarding/welcome';
  static const home = '/home';
  static const main = '/main';

  // Onboarding flow
  static const onboardingImportApi = '/onboarding/import-api';
  static const onboardingPermission1 = '/onboarding/permission1';
  static const onboardingPermission2 = '/onboarding/permission2';
  static const onboardingPermission3 = '/onboarding/permission3';

  // Standalone routes
  static const slotAssignments = '/produced/slot-assignments';
  static const backgroundProductionSettings = '/background-production-settings';

  // Main shell routes
  static const mainNode = '/main/node';
  static const mainNodeWonSlots = '/main/node/won-slots';
  static const mainNodeProducedBlocks = '/main/node/produced-blocks';
  static const mainNodeProductionStats = '/main/node/production-stats';
  static const mainNodeBlockDetails = '/main/node/block-details';
  static const mainNodeMempool = '/main/node/mempool';
  static const mainSettings = '/main/settings';
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
        builder: (context, state) => const WelcomeClaimScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingImportApi,
        builder: (context, state) => const NewUxOnboardingImportApiScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermission1,
        builder: (context, state) => const Permission1Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermission2,
        builder: (context, state) => const Permission2Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingPermission3,
        builder: (context, state) => const Permission3Screen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.slotAssignments,
        builder: (context, state) => const SlotAssignmentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.backgroundProductionSettings,
        builder: (context, state) => const BackgroundProductionSettingsScreen(),
      ),
      // Redirect bare /main to default tab
      GoRoute(
        path: AppRoutes.main,
        redirect: (context, state) => AppRoutes.mainNode,
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainApp(currentLocation: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.mainNode,
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const NodeStatusScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.mainNodeWonSlots,
            builder: (context, state) => const NodeWonSlotsScreen(),
          ),
          GoRoute(
            path: AppRoutes.mainNodeProducedBlocks,
            builder: (context, state) => const ProducedBlocksScreen(),
          ),
          GoRoute(
            path: AppRoutes.mainNodeProductionStats,
            builder: (context, state) => const SlotProductionStatsScreen(),
          ),
          GoRoute(
            path: AppRoutes.mainNodeBlockDetails,
            builder: (context, state) {
              final block = state.extra as RpcStatusBlockInfo;
              return BlockDetailsScreen(block: block);
            },
          ),
          GoRoute(
            path: AppRoutes.mainNodeMempool,
            builder: (context, state) => const MempoolDetailsScreen(),
          ),
          GoRoute(
            path: AppRoutes.mainSettings,
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
        // Allow onboarding routes
        if (currentLocation.startsWith('/onboarding/')) {
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

      // Redirect from splash and onboarding to home if user already has an account
      if (currentLocation == AppRoutes.splash ||
          currentLocation.startsWith('/onboarding/')) {
        LoggingService.instance.trace('Redirecting $currentLocation to /home');
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
