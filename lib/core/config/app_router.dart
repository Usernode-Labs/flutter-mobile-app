import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/auth/screens/auth_landing_screen.dart';
import 'package:crypto_mobile_app/features/auth/screens/auth_email_screen.dart';
import 'package:crypto_mobile_app/features/auth/screens/auth_password_screen.dart';
import 'package:crypto_mobile_app/features/auth/screens/auth_otp_screen.dart';
import 'package:crypto_mobile_app/features/auth/screens/auth_set_password_screen.dart';
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
import 'package:crypto_mobile_app/features/profile/screens/profile_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/settings_screen.dart';
import 'package:crypto_mobile_app/features/terms/screens/terms_screen.dart';
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
import 'package:crypto_mobile_app/features/dapps/providers/pinned_dapps_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/home/home_tab_provider.dart';
import 'package:crypto_mobile_app/features/leaderboard/screens/leaderboard_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/perf_benchmark_ui.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_result_detail_screen.dart';
import 'package:crypto_mobile_app/features/perf/presentation/screens/device_benchmark_run_screen.dart';
import 'package:crypto_mobile_app/features/settings/screens/http_debug_logs_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/scan_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/send_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_success_screen.dart';
import 'package:crypto_mobile_app/features/wallet/screens/transaction_failed_screen.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/app_deep_link_allowlist.dart';
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

  // v3 auth flow
  static const authLanding = '/auth';
  static const authEmail = '/auth/email';
  static const authPassword = '/auth/password';
  static const authOtp = '/auth/otp';
  static const authSetPassword = '/auth/set-password';

  // Standalone routes
  static const slotAssignments = '/produced/slot-assignments';
  static const producedBlockDetails = '/produced/block-details';

  // Wallet routes
  static const walletSend = '/wallet/send';
  static const walletScan = '/wallet/scan';
  static const walletSendSuccess = '/wallet/send/success';
  static const walletSendFailed = '/wallet/send/failed';

  // Challenge routes
  static const challengeDetail = '/challenges/detail';
  static const epochPerformance = '/challenges/epoch-performance';
  static const leaderboard = '/challenges/leaderboard';

  // Profile (Fair Rewards shell): "what I earned" + Settings entry.
  static const profile = '/profile';
  static const profileSettings = '/profile/settings';
  static const dapps = '/dapps';
  static const dappDetail = '/dapps/:slug';
  static const dappPinned = '/dapps/pinned/:id';
  static const deviceBenchmark = '/settings/device-benchmark';
  static const deviceBenchmarkRun = '/settings/device-benchmark/run';
  static const deviceBenchmarkResultDetail =
      '/settings/device-benchmark/result';
  static const httpDebugLogs = '/settings/http-debug-logs';

  /// Terms page opened from Settings or the withheld-token notice.
  static const terms = '/settings/terms';

  static String dappDetailFor(String slug) => '/dapps/$slug';
  static String dappPinnedFor(String id) => '/dapps/pinned/$id';

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

const _authRoutes = <String>[
  AppRoutes.authLanding,
  AppRoutes.authEmail,
  AppRoutes.authPassword,
  AppRoutes.authOtp,
  AppRoutes.authSetPassword,
];

/// First-stage auth gate. Returns a redirect target, or null to defer to the
/// existing account/onboarding logic. Pure for unit testing.
String? authRedirect(AuthStatus status, String location) {
  final isAuthRoute = _authRoutes.contains(location);
  switch (status) {
    case AuthStatus.unknown:
      return null; // still loading; don't bounce
    case AuthStatus.unauthenticated:
      return isAuthRoute ? null : AppRoutes.authLanding;
    case AuthStatus.guest:
      // Guests may enter the auth flow — that is how they upgrade to a real
      // account (Settings shows them a "Log in" tile). Bouncing them off auth
      // routes the way we bounce authenticated users sent them landing ->
      // splash -> guestRedirect -> dapps, making the tile a no-op.
      return null;
    case AuthStatus.authenticated:
      return isAuthRoute ? AppRoutes.splash : null;
  }
}

/// Whether the account/onboarding logic below the auth gate may run.
///
/// That logic assumes a signed-in user with a local account. Only
/// [AuthStatus.authenticated] qualifies. In particular [AuthStatus.unknown]
/// must not: the session has not been read yet, and letting it through meant an
/// unauthenticated user could be routed by account state — landing on `/home`
/// or onboarding for a frame before being corrected. Pure for unit testing.
bool authGateAllowsAccountLogic(AuthStatus status) =>
    status == AuthStatus.authenticated;

/// Where a guest should be routed. Guests never enter node onboarding: from
/// splash/onboarding send them to the Dapps tab; elsewhere return null so they
/// can roam the app shell. Pure for unit testing.
String? guestRedirect(String location) {
  if (location == AppRoutes.splash || location.startsWith('/onboarding/')) {
    return AppRoutes.dapps;
  }
  return null;
}

/// A ChangeNotifier that listens to Riverpod provider changes and notifies GoRouter
/// This bridges Riverpod's state management with GoRouter's refresh mechanism
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(this._ref) {
    // Listen to auth status changes (v3 auth gate)
    _ref.listen<AuthStatus>(
      authStatusProvider,
      (previous, next) {
        notifyListeners();
      },
    );
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
  // Do NOT ref.watch state providers here: a watch rebuilds this provider
  // when they change (e.g. loading -> data right after launch), which
  // creates a brand-new GoRouter and resets navigation to /splash — this
  // stomped cold-start deep links from homescreen widgets. The redirect
  // guard reads fresh values on every run instead, and
  // GoRouterRefreshStream re-runs it whenever they change. The listen
  // keeps the bootstrap chain (season/registration freshness) alive
  // without triggering rebuilds.
  ref.listen(leaderboardBootstrapProvider, (_, __) {});

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
        path: AppRoutes.authLanding,
        builder: (context, state) => const AuthLandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.authEmail,
        builder: (context, state) => const AuthEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPassword,
        builder: (context, state) => const AuthPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authOtp,
        builder: (context, state) => const AuthOtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.authSetPassword,
        builder: (context, state) => const AuthSetPasswordScreen(),
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
        path: AppRoutes.httpDebugLogs,
        builder: (context, state) => const HttpDebugLogsScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsScreen(),
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
        // The detail screen is driven entirely by the EnrichedChallenge passed
        // via `extra` from the list tap. `extra` is in-memory only, so it's
        // null after a hot restart / deep link to this path — fall back to home
        // instead of crashing on the cast below.
        redirect: (context, state) =>
            state.extra is EnrichedChallenge ? null : AppRoutes.home,
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
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSettings,
        // SettingsScreen is a bare root Scaffold; wrap it with a back app bar
        // so it works as a pushed page from Profile.
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.dapps,
        builder: (context, state) => const HomeScreen(
          initialTab: HomeTab.dapps,
        ),
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
      // Fresh reads on every evaluation (see note at the top of this
      // provider); GoRouterRefreshStream re-runs this guard when any of
      // these change.
      final hasAny = ref.read(hasAnyAccountProvider).maybeWhen(
            data: (v) => v,
            orElse: () => null,
          );
      final hasCompletedOnboarding =
          ref.read(hasCompletedOnboardingProvider).maybeWhen(
                data: (v) => v,
                orElse: () => null,
              );
      final registrationFreshness = ref.read(registrationFreshnessProvider);

      final currentLocation = state.matchedLocation;
      final requestUri = state.uri;

      _log.trace(
          'Redirect guard called - location: $currentLocation, hasAny: $hasAny, onboardingComplete: $hasCompletedOnboarding');

      // Disallowed deep links are refused regardless of auth state, before the
      // gate. A blocked URI is not an authorisation question: leaving it open
      // while the session resolves — or for a guest, who returns below without
      // ever reaching this check — would let it survive indefinitely.
      if (shouldBlockUsernodeDeepLink(requestUri)) {
        _log.warn('Blocked unsupported app deep link: $requestUri');
        return AppRoutes.home;
      }

      // v3 auth gate runs next. It forces unauthenticated users (including
      // existing users upgrading) to the auth landing before any account or
      // onboarding logic applies. Authenticated/guest users fall through.
      final authStatus = ref.read(authStatusProvider);
      final authGate = authRedirect(authStatus, currentLocation);
      if (authGate != null) return authGate;

      if (!authGateAllowsAccountLogic(authStatus)) {
        // Guests never enter node onboarding — they browse. Land them on Dapps
        // from splash/onboarding; otherwise let them roam the app shell
        // (account-gated screens surface their own "sign in to view" gate).
        if (authStatus == AuthStatus.guest) {
          return guestRedirect(currentLocation);
        }
        // unauthenticated on an auth route: allow it.
        // unknown: the session has not been read yet — stay put rather than let
        // account state decide, which would flash /home or onboarding before
        // GoRouterRefreshStream corrects us.
        return null;
      }

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
