import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/splash/screens/splash_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/welcome_claim_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/import_api_account_screen.dart';
import 'package:crypto_mobile_app/features/onboarding/screens/stale_registration_screen.dart';
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
import 'package:crypto_mobile_app/features/node/screens/block_details_screen.dart';
import 'package:crypto_mobile_app/features/challenges/challenge_mappers.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_detail_screen.dart';
import 'package:crypto_mobile_app/features/zk_identity/screens/zk_identity_flow_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/challenge_detail_screen.dart';
import 'package:crypto_mobile_app/features/challenges/screens/epoch_performance_screen.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:crypto_mobile_app/features/dapps/providers/dapps_provider.dart';
import 'package:crypto_mobile_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_result_detail_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_run_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/scan_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_success_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_failed_screen.dart';
import 'package:crypto_mobile_app/features/wallet/burst/burst_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
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
  static const staleRegistration = '/stale-registration';

  // Standalone routes
  static const slotAssignments = '/produced/slot-assignments';
  static const producedBlockDetails = '/produced/block-details';

  // Wallet routes
  static const walletSend = '/wallet/send';
  static const walletScan = '/wallet/scan';
  static const walletBurst = '/wallet/burst';
  static const walletSendSuccess = '/wallet/send/success';
  static const walletSendFailed = '/wallet/send/failed';

  // Challenge routes
  static const challengeDetail = '/challenges/detail';
  static const epochPerformance = '/challenges/epoch-performance';
  static const leaderboard = '/challenges/leaderboard';
  static const dappDetail = '/dapps/:slug';
  static const deviceBenchmark = '/settings/device-benchmark';
  static const deviceBenchmarkRun = '/settings/device-benchmark/run';
  static const deviceBenchmarkResultDetail =
      '/settings/device-benchmark/result';

  static String dappDetailFor(String slug) => '/dapps/$slug';

  // ZK Identity
  static const zkIdentityDetail = '/challenges/zk-identity';
  static const zkIdentityFlow = '/challenges/zk-identity/flow';

  // Main shell routes
  static const mainNode = '/main/node';
  static const mainNodeWonSlots = '/main/node/won-slots';
  static const mainNodeBlockDetails = '/main/node/block-details';
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
    // Listen to registration freshness changes (stale detection)
    _ref.listen<RegistrationFreshness>(
      registrationFreshnessProvider,
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
  // Watch freshness + bootstrap so the router reacts to stale detection.
  final registrationFreshness = ref.watch(registrationFreshnessProvider);
  ref.watch(leaderboardBootstrapProvider);

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
        path: AppRoutes.staleRegistration,
        builder: (context, state) => const StaleRegistrationScreen(),
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
        path: AppRoutes.walletScan,
        builder: (context, state) => const ScanScreen(),
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
        path: AppRoutes.walletBurst,
        builder: (context, state) => const BurstScreen(),
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
                            TextButton(
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(AppRoutes.home);
                                }
                              },
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return DappWebViewScreen(url: dapp.url, name: dapp.name);
                },
              );
            },
          );
        },
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

      // Block app usage when registration belongs to a previous season.
      if (registrationFreshness == RegistrationFreshness.stale &&
          currentLocation != AppRoutes.staleRegistration &&
          currentLocation != AppRoutes.onboardingImportApi) {
        return AppRoutes.staleRegistration;
      }

      // Allow stale registration screen (lives outside /onboarding/)
      if (currentLocation == AppRoutes.staleRegistration) {
        return null;
      }

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
