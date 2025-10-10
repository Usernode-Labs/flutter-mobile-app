import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/presentation/screens/single_account_onboarding_screen.dart';
import 'package:crypto_mobile_app/app/main_app.dart';
import 'package:crypto_mobile_app/features/home/presentation/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/presentation/screens/produced_blocks_screen.dart';
import 'package:crypto_mobile_app/features/dapps/presentation/screens/dapps_screen.dart';
import 'package:crypto_mobile_app/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:crypto_mobile_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:crypto_mobile_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:crypto_mobile_app/core/di/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const main = '/main';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final key = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: key,
    observers: SentryUtil.navigatorObservers(),
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const SingleAccountOnboardingScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
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

      if (hasAny == null) return null; // unknown yet

      final goingToOnboarding = state.matchedLocation == AppRoutes.onboarding;
      final inMain = state.matchedLocation.startsWith('/main');

      if (hasAny && goingToOnboarding) return '/main/home';
      if (!hasAny && inMain) return AppRoutes.onboarding;
      return null;
    },
  );
});
