import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/account_mode_selection_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/create_new_account_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/import_seed_phrase_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:crypto_mobile_app/app/main_app.dart';
import 'package:crypto_mobile_app/features/home/presentation/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/dapps/presentation/screens/dapps_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/receive_screen.dart';
import 'package:crypto_mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:crypto_mobile_app/features/rewards/presentation/screens/rewards_breakdown_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

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

final appRouterProvider = Provider<GoRouter>((ref) {
  final key = GlobalKey<NavigatorState>();

  // Watch the provider to make router reactive
  ref.watch(hasAnyAccountProvider);

  return GoRouter(
    navigatorKey: key,
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
        builder: (context, state, child) => MainApp(currentLocation: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/main/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/main/node',
            builder: (context, state) => const NodeStatusScreen(),
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
            path: '/main/node/mempool',
            builder: (context, state) => const MempoolDetailsScreen(),
          ),
          GoRoute(
            path: '/main/dapps',
            builder: (context, state) => const DAppsScreen(),
          ),
          // Optional routes for wallet/profile (hidden from bottom nav by flags)
          GoRoute(
            path: '/main/wallet',
            builder: (context, state) => const WalletScreen(),
          ),
          GoRoute(
            path: '/main/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final hasAny = ref
          .read(hasAnyAccountProvider)
          .maybeWhen(data: (v) => v, orElse: () => null);

      final currentLocation = state.matchedLocation;

      Log.d('ROUTER', 'Redirect guard called - location: $currentLocation, hasAny: $hasAny');

      // Still loading account state
      if (hasAny == null) {
        Log.d('ROUTER', 'Account state loading - allowing navigation');
        return null;
      }

      // Define public routes that don't require an account
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
      ];

      final isPublicRoute = publicRoutes.contains(currentLocation);
      Log.d('ROUTER', 'Route $currentLocation is ${isPublicRoute ? "public" : "private"}');

      // No account exists
      if (!hasAny) {
        Log.d('ROUTER', 'No account exists');
        // Splash should redirect to onboarding (transient route)
        if (currentLocation == AppRoutes.splash) {
          Log.d('ROUTER', 'Redirecting splash to onboarding');
          return AppRoutes.onboarding;
        }
        // Allow onboarding and account setup routes
        if (currentLocation == AppRoutes.onboarding ||
            currentLocation == '/create-new-account' ||
            currentLocation == '/import-seed-phrase' ||
            currentLocation == '/identity-verification') {
          Log.d('ROUTER', 'Allowing onboarding route');
          return null;
        }
        // Redirect all other routes to onboarding
        Log.d('ROUTER', 'Redirecting private route to onboarding');
        return AppRoutes.onboarding;
      }

      // Account exists
      Log.d('ROUTER', 'Account exists');

      // Allow identity verification and account setup during onboarding flow
      if (currentLocation == '/identity-verification' ||
          currentLocation == '/create-new-account' ||
          currentLocation == '/import-seed-phrase') {
        Log.d('ROUTER', 'Allowing onboarding flow route');
        return null;
      }

      // Redirect from splash and onboarding to home if user already has an account
      if (currentLocation == AppRoutes.splash ||
          currentLocation == AppRoutes.onboarding) {
        Log.d('ROUTER', 'Redirecting $currentLocation to /main/home');
        return '/main/home';
      }

      // Allow all other routes when account exists
      Log.d('ROUTER', 'Allowing route: $currentLocation');
      return null;
    },
  );
});
