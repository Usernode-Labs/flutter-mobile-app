import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/welcome_claim_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/import_api_account_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/exact_alarm_permission1_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/battery_permission2_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/notification_permission3_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/welcome_setup_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/onboarding_battery_complete_screen.dart';
import 'package:crypto_mobile_app/features/home/screens/home_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/slot_assignments_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/produced_block_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_status_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_won_slots_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/mempool_details_screen.dart';
import 'package:crypto_mobile_app/features/node/screens/node_peers_screen.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_detail_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_flow_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenge_detail_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/epoch_performance_screen.dart';
import 'package:crypto_mobile_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_success_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_failed_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';

final _log = LoggingService.instance.withTag('usernode/Router');

class AppRoutes {
  // Core routes
  static const splash = '/splash';
  static const onboarding = '/onboarding/welcome';
  static const home = '/home';
  static const homeSlash = '/';
  static const main = '/main';

  // Onboarding flow
  static const onboardingImportApi = '/onboarding/import-api';
  static const onboardingWelcomeSetup = '/onboarding/welcome-setup';
  static const onboardingExactAlarmPermission1 =
      '/onboarding/exact-alarm-permission1';
  static const onboardingBatteryPermission2 = '/onboarding/battery-permission2';
  static const onboardingNotificationPermission3 =
      '/onboarding/notification-permission3';
  static const onboardingBatteryComplete = '/onboarding/battery-complete';

  // Standalone routes
  static const slotAssignments = '/produced/slot-assignments';
  static const producedBlockDetails = '/produced/block-details';

  // Wallet routes
  static const walletSend = '/wallet/send';
  static const walletSendSuccess = '/wallet/send/success';
  static const walletSendFailed = '/wallet/send/failed';

  // Challenge routes
  static const challengeDetail = '/challenges/detail';
  static const epochPerformance = '/challenges/epoch-performance';
  static const leaderboard = '/challenges/leaderboard';

  // ZK Identity
  static const zkIdentityDetail = '/challenges/zk-identity';
  static const zkIdentityFlow = '/challenges/zk-identity/flow';

  // Main shell routes
  static const mainNode = '/main/node';
  static const mainNodeWonSlots = '/main/node/won-slots';
  static const mainNodeMempool = '/main/node/mempool';
  static const mainNodePeers = '/main/node/peers';
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
    // Listen to hasCompletedOnboardingProvider changes
    _ref.listen<AsyncValue<bool>>(
      hasCompletedOnboardingProvider,
      (previous, next) {
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
  // Watch providers to make router reactive and capture their values
  final hasAnyAccountAsync = ref.watch(hasAnyAccountProvider);
  final hasCompletedOnboardingAsync = ref.watch(hasCompletedOnboardingProvider);

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
        builder: (context, state) => const OnboardingImportApiAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingWelcomeSetup,
        builder: (context, state) => const WelcomeSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingExactAlarmPermission1,
        builder: (context, state) => const ExactAlarmPermission1Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingBatteryPermission2,
        builder: (context, state) => const BatteryPermission2Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingNotificationPermission3,
        builder: (context, state) => const NotificationPermission3Screen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingBatteryComplete,
        builder: (context, state) => const OnboardingBatteryCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeSlash,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.slotAssignments,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SlotAssignmentsScreen(args: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.producedBlockDetails,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ProducedBlockDetailsScreen(args: extra);
        },
      ),
      // Won slots screen - outside shell route (no bottom nav)
      GoRoute(
        path: AppRoutes.mainNodeWonSlots,
        builder: (context, state) => const NodeWonSlotsScreen(),
      ),
      // Redirect bare /main to mainNode
      GoRoute(
        path: AppRoutes.main,
        redirect: (context, state) => AppRoutes.mainNode,
      ),
      GoRoute(
        path: AppRoutes.mainNode,
        builder: (context, state) => const NodeStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.mainNodeMempool,
        builder: (context, state) => const MempoolDetailsScreen(),
      ),
      GoRoute(
        path: AppRoutes.mainNodePeers,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final peers = extra['peers'] as List<RpcPeerInfo>;
          final peerId = extra['peerId'] as String?;
          return NodePeersScreen(peers: peers, peerId: peerId);
        },
      ),
      GoRoute(
        path: AppRoutes.walletSend,
        builder: (context, state) => const SendScreen(),
      ),
      GoRoute(
        path: AppRoutes.walletSendSuccess,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TransactionSuccessScreen(
            amount: extra['amount'] as String,
            tokenSymbol: extra['tokenSymbol'] as String,
            recipientAddress: extra['recipientAddress'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.walletSendFailed,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return TransactionFailedScreen(
            errorMessage: extra['errorMessage'] as String,
          );
        },
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
        path: AppRoutes.challengeDetail,
        builder: (context, state) {
          final enriched = state.extra as EnrichedChallenge;
          return ChallengeDetailScreen(challenge: enriched);
        },
      ),
      GoRoute(
        path: AppRoutes.epochPerformance,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return EpochPerformanceScreen(
            initialEpoch: extra['initialEpoch'] as int,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardScreen(),
      ),
    ],
    redirect: (context, state) {
      final hasAny = hasAnyAccountAsync.maybeWhen(
        data: (v) => v,
        orElse: () => null,
      );
      final hasCompletedOnboarding = hasCompletedOnboardingAsync.maybeWhen(
        data: (v) => v,
        orElse: () => null,
      );

      final currentLocation = state.matchedLocation;

      _log.trace(
          'Redirect guard called - location: $currentLocation, hasAny: $hasAny, onboardingComplete: $hasCompletedOnboarding');

      // Still loading state
      if (hasAny == null || hasCompletedOnboarding == null) {
        _log.trace('State loading - allowing navigation');
        return null;
      }

      // Define public routes that don't require an account
      const publicRoutes = [
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.onboardingImportApi,
        AppRoutes.onboardingWelcomeSetup,
      ];

      final isPublicRoute = publicRoutes.contains(currentLocation);
      _log.trace(
          'Route $currentLocation is ${isPublicRoute ? "public" : "private"}');

      // No account exists
      if (!hasAny) {
        _log.trace('No account exists');
        // Splash should redirect to onboarding (transient route)
        if (currentLocation == AppRoutes.splash) {
          _log.trace('Redirecting splash to onboarding');
          return AppRoutes.onboarding;
        }
        // Allow onboarding routes
        if (currentLocation.startsWith('/onboarding/')) {
          _log.trace('Allowing onboarding route');
          return null;
        }
        // Redirect all other routes to onboarding
        _log.trace('Redirecting private route to onboarding');
        return AppRoutes.onboarding;
      }

      // Account exists but onboarding NOT completed - allow onboarding routes
      if (!hasCompletedOnboarding) {
        _log.trace('Account exists but onboarding not completed');
        if (currentLocation.startsWith('/onboarding/')) {
          _log.trace('Allowing onboarding route during onboarding flow');
          return null;
        }
        // Splash should redirect to first permission screen
        if (currentLocation == AppRoutes.splash) {
          _log.trace('Redirecting splash to onboarding welcome-setup');
          return AppRoutes.onboardingWelcomeSetup;
        }
      }

      // Account exists AND onboarding completed
      _log.trace('Account exists and onboarding completed');

      // Redirect from splash and onboarding to home
      if (currentLocation == AppRoutes.splash ||
          currentLocation.startsWith('/onboarding/')) {
        _log.trace('Redirecting $currentLocation to /home');
        return AppRoutes.home;
      }

      // Allow all other routes when account exists
      _log.trace('Allowing route: $currentLocation');
      return null;
    },
  );
});
