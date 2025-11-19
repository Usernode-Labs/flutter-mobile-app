import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/account_mode_selection_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/create_new_account_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/import_seed_phrase_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:crypto_mobile_app/core/main_app.dart';
import 'package:crypto_mobile_app/features/home/presentation/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/block_details_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/notification_details_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/slot_production_stats_screen.dart';
import 'package:crypto_mobile_app/features/dapps/presentation/screens/dapps_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/receive_screen.dart';
import 'package:crypto_mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/notification_settings_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/background_production_settings_screen.dart';
import 'package:crypto_mobile_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/screens/rewards_breakdown_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/core/models/notification_payload.dart';

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
        path: '/create-new-account',
        builder: (context, state) {
          final mnemonic = state.uri.queryParameters['mnemonic'] ?? '';
          return CreateNewAccountScreen(mnemonic: mnemonic);
        },
      ),
      GoRoute(
        path: '/import-seed-phrase',
        builder: (context, state) => const ImportSeedPhraseScreen(),
      ),
      GoRoute(
        path: '/identity-verification',
        builder: (context, state) {
          final accountId = state.uri.queryParameters['accountId'];
          return IdentityVerificationScreen(accountId: accountId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/background-production-settings',
        builder: (context, state) => const BackgroundProductionSettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/send',
        builder: (context, state) => const SendScreen(),
      ),
      GoRoute(
        path: '/receive',
        builder: (context, state) => const ReceiveScreen(),
      ),
      GoRoute(
        path: '/rewards',
        builder: (context, state) => const RewardsBreakdownScreen(),
      ),
      // Redirect bare /main to default tab
      GoRoute(
        path: AppRoutes.main,
        redirect: (context, state) => '/main/home',
      ),
      ShellRoute(
        builder: (context, state, child) =>
            MainApp(currentLocation: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/main/home',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const HomeScreen(),
            ),
          ),
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
            path: '/main/node/notification-details',
            builder: (context, state) {
              final payload = state.extra as NotificationPayload;
              return NotificationDetailsScreen(payload: payload);
            },
          ),
          GoRoute(
            path: '/main/dapps',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const DAppsScreen(),
            ),
          ),
          // Optional routes for wallet/profile (hidden from bottom nav by flags)
          GoRoute(
            path: '/main/wallet',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const WalletScreen(),
            ),
          ),
          GoRoute(
            path: '/main/profile',
            pageBuilder: (context, state) => _buildPageWithFade(
              state,
              const ProfileScreen(),
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

      LoggingService.instance.trace(
          'Redirect guard called - location: $currentLocation, hasAny: $hasAny',
          tag: 'ROUTER');

      // Still loading account state
      if (hasAny == null) {
        LoggingService.instance.trace(
            'Account state loading - allowing navigation',
            tag: 'ROUTER');
        return null;
      }

      // Define public routes that don't require an account
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
      ];

      final isPublicRoute = publicRoutes.contains(currentLocation);
      LoggingService.instance.trace(
          'Route $currentLocation is ${isPublicRoute ? "public" : "private"}',
          tag: 'ROUTER');

      // No account exists
      if (!hasAny) {
        LoggingService.instance.trace('No account exists', tag: 'ROUTER');
        // Splash should redirect to onboarding (transient route)
        if (currentLocation == AppRoutes.splash) {
          LoggingService.instance
              .debug('Redirecting splash to onboarding', tag: 'ROUTER');
          return AppRoutes.onboarding;
        }
        // Allow onboarding and account setup routes
        if (currentLocation == AppRoutes.onboarding ||
            currentLocation == '/create-new-account' ||
            currentLocation == '/import-seed-phrase' ||
            currentLocation == '/identity-verification') {
          LoggingService.instance
              .debug('Allowing onboarding route', tag: 'ROUTER');
          return null;
        }
        // Redirect all other routes to onboarding
        LoggingService.instance
            .debug('Redirecting private route to onboarding', tag: 'ROUTER');
        return AppRoutes.onboarding;
      }

      // Account exists
      LoggingService.instance.trace('Account exists', tag: 'ROUTER');

      // Allow identity verification and account setup during onboarding flow
      if (currentLocation == '/identity-verification' ||
          currentLocation == '/create-new-account' ||
          currentLocation == '/import-seed-phrase') {
        LoggingService.instance
            .debug('Allowing onboarding flow route', tag: 'ROUTER');
        return null;
      }

      // Redirect from splash and onboarding to home if user already has an account
      if (currentLocation == AppRoutes.splash ||
          currentLocation == AppRoutes.onboarding) {
        LoggingService.instance
            .debug('Redirecting $currentLocation to /main/home', tag: 'ROUTER');
        return '/main/home';
      }

      // Allow all other routes when account exists
      LoggingService.instance
          .debug('Allowing route: $currentLocation', tag: 'ROUTER');
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
