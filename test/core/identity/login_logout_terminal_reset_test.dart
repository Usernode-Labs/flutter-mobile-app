import 'dart:io';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/session_authority_test_helpers.dart';

final _resetProbeProvider = Provider<_ResetGraphProbe>((ref) {
  throw StateError('A reset graph probe override is required');
});

final _mountedResetProbeProvider = Provider<_ResetGraphProbe>((ref) {
  final probe = ref.watch(_resetProbeProvider)..mount();
  ref.onDispose(probe.dispose);
  return probe;
});

class _NoopLogoutRepository extends AuthRepository {
  @override
  Future<void> logout(String sessionToken) async {}
}

SessionController _controller({
  required ScriptedSessionAuthority authority,
  required SessionTerminalReset terminalReset,
  SignOutFence? signOutFence,
  Future<bool> Function()? clearWebSessionData,
  Future<bool> Function()? rotateNativeGeneration,
  Future<bool> Function()? clearSessionNotifications,
}) =>
    SessionController(
      tokenStore: AuthTokenStore(),
      guestFlag: AuthGuestFlag(),
      repository: _NoopLogoutRepository(),
      sessionAuthority: authority,
      newAuthorityId: (kind) => switch (kind) {
        'session' => 'session-a',
        'transition' => 'login-a',
        'credential' => 'credential-a',
        'successor' => 'logged-out-b',
        'retirement' => 'retire-a',
        _ => throw StateError('Unexpected authority id: $kind'),
      },
      suspendNode: () async {},
      retireRuntimeAuthority: ({
        required directory,
        required sessionId,
        required transitionId,
      }) async =>
          true,
      clearWebSessionData: clearWebSessionData ?? () async => true,
      rotateNativeGeneration: rotateNativeGeneration ?? () async => true,
      clearSessionNotifications: clearSessionNotifications ?? () async => true,
      signOutFence: signOutFence ?? InMemorySignOutFence(),
      terminalReset: terminalReset,
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const alarmChannel = MethodChannel('com.usernode.app/alarm');

  late Directory testRoot;
  late Map<String, Directory> appDirectories;
  late AppResetService resetService;
  late PlatformAlarmService platformAlarms;
  late List<MethodCall> nativeCalls;
  late String? nativeIncarnation;
  late int incarnationSerial;

  setUp(() async {
    IdentitySnapshots.reset();
    NetworkPrefs.setActiveBucket(null, guest: true);
    SharedPreferences.setMockInitialValues({
      'auth:v3:guest': true,
      'old_preference': 'must disappear',
      'testnet:accounts:activeId': 'old-account',
    });
    FlutterSecureStorage.setMockInitialValues({
      'old_secret': 'must disappear',
    });

    testRoot = await Directory.systemTemp.createTemp('usernode-reset-test-');
    appDirectories = {
      'getApplicationSupportDirectory':
          await Directory('${testRoot.path}/support').create(),
      'getApplicationDocumentsDirectory':
          await Directory('${testRoot.path}/documents').create(),
      'getApplicationCacheDirectory':
          await Directory('${testRoot.path}/cache').create(),
      'getTemporaryDirectory':
          await Directory('${testRoot.path}/temporary').create(),
    };
    for (final directory in appDirectories.values) {
      await File('${directory.path}/old-data').writeAsString('old');
      final nested = await Directory('${directory.path}/nested').create();
      await File('${nested.path}/old-data').writeAsString('old');
    }

    nativeCalls = [];
    nativeIncarnation = null;
    incarnationSerial = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      alarmChannel,
      (call) async {
        nativeCalls.add(call);
        switch (call.method) {
          case 'hasPostNotificationsPermission':
          case 'hasExactAlarmPermission':
            return true;
          case 'ensureApplicationIncarnation':
            return nativeIncarnation ??= 'incarnation-${++incarnationSerial}';
          case 'invalidateApplicationIncarnation':
          case 'clearNativeResetState':
            nativeIncarnation = null;
            return true;
          case 'rotateApplicationIncarnation':
            return nativeIncarnation = 'incarnation-${++incarnationSerial}';
          case 'clearSessionNotifications':
            return true;
          case 'stopPersistentForegroundService':
          case 'stopForegroundService':
          case 'releaseWakelock':
          case 'cancelAllAlarms':
          case 'cancelAlarmWatchdog':
          case 'clearWebSessionData':
            return true;
          case 'enterTerminalReset':
            return null;
          default:
            throw MissingPluginException(call.method);
        }
      },
    );
    platformAlarms = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
      platform: TargetPlatform.android,
    );
    expect(await platformAlarms.initialize(), isTrue);

    resetService = AppResetService.test(
      resetDirectories: () async => appDirectories.values.toList(),
      platformAlarms: platformAlarms,
    );

    await SentryUtil.bootstrap(
      () {},
      settings: const SentrySettings(
        dsn: 'https://public@example.com/1',
        environment: 'test',
        tracesSampleRate: 0,
        profilesSampleRate: 0,
        enableBreadcrumbs: false,
        enablePerformanceTracking: false,
      ),
    );
    expect(SentryUtil.enabled, isTrue);
    await SentryUtil.setUser(id: 'old-account');
    AppLifecycleLogger.register();
    AppLifecycleLogger.onForegroundResume = () {};
  });

  tearDown(() async {
    AppLifecycleLogger.closeForTerminalReset();
    await Sentry.close();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(alarmChannel, null);
    if (await testRoot.exists()) {
      await testRoot.delete(recursive: true);
    }
  });

  testWidgets(
      'initial login stays live and a terminal boundary erases the complete '
      'incarnation', (tester) async {
    final graphProbe = _ResetGraphProbe();
    final container = ProviderContainer(overrides: [
      _resetProbeProvider.overrideWithValue(graphProbe),
    ]);
    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: container,
      resetService: resetService,
      child: const _ResetGraphView(),
    ));
    // Sentry's app-start integration owns a fixed three-second idle timer on
    // newer Flutter test bindings. Advance fake time so the reset assertions,
    // rather than SDK bookkeeping, determine this test's result.
    await tester.pump(const Duration(seconds: 3));
    expect(graphProbe.mounted, isTrue);

    final oldIncarnation = nativeIncarnation!;
    var nativeEventCalls = 0;
    platformAlarms.setNativeEventCallback((_, __) async {
      nativeEventCalls += 1;
      return true;
    });
    nativeCalls.clear();

    final controller = _controller(
      authority: activationSessionAuthority(
        accountId: 'account-a',
        address: 'address-a',
        userNamespace: 'aaaaaaaaaaaaaaa2',
        loggedOutMode: 'guest',
      ),
      terminalReset: ({required reason, prepareNextLaunch}) =>
          resetService.resetAndTerminate(
        reason: reason,
        prepareNextLaunch: prepareNextLaunch,
      ),
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.state.phase, IdentityPhase.guest);

    final loggedIn = await tester.runAsync(
      () => controller.completeLogin(
        const AuthSession(
          token: 'new-session',
          participant: Participant(
            id: 2,
            email: 'two@example.com',
            emailConfirmed: true,
            identityHash: 'aaaaaaaaaaaaaaa2',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(loggedIn, isTrue);
    expect(controller.state.phase, IdentityPhase.reconciling);
    expect(controller.state.participantId, 2);
    expect(find.text('functional graph'), findsOneWidget);
    expect(graphProbe.mounted, isTrue);
    expect(nativeCalls, isEmpty);
    expect(SentryUtil.enabled, isTrue);
    expect(AppLifecycleLogger.isRegistered, isTrue);
    final prefsBeforeLogout = await SharedPreferences.getInstance();
    expect(prefsBeforeLogout.getString('old_preference'), 'must disappear');
    expect(
      await const FlutterSecureStorage().read(key: 'old_secret'),
      'must disappear',
    );
    expect(
      await AuthTokenStore().readForIdentity(controller.state),
      'new-session',
    );

    // Voluntary sign-out is no longer terminal (see the sign-out test below),
    // so the incarnation-erasure contract is driven here by the boundary that
    // still is one: swapping an authenticated session for guest mode.
    await tester.runAsync(controller.continueAsGuest);
    await tester.pump();

    expect(controller.state.phase, IdentityPhase.transitioning);
    expect(find.text('Switched to guest'), findsOneWidget);
    expect(graphProbe.mounted, isFalse);
    expect(graphProbe.mountCount, 1);
    expect(AppLifecycleLogger.isRegistered, isFalse);
    expect(AppLifecycleLogger.onForegroundResume, isNull);
    expect(SentryUtil.enabled, isFalse);
    expect(
      nativeCalls.map((call) => call.method),
      [
        'invalidateApplicationIncarnation',
        'clearWebSessionData',
        'clearNativeResetState',
        'enterTerminalReset',
      ],
    );
    expect(
      nativeCalls.last.arguments,
      {'clearApplicationData': true},
    );
    expect(nativeIncarnation, isNull);

    SentryUser? sentryUser;
    await Sentry.configureScope((scope) => sentryUser = scope.user);
    expect(sentryUser, isNull);
    await SentryUtil.setUser(id: 'late-old-account');
    await Sentry.configureScope((scope) => sentryUser = scope.user);
    expect(sentryUser, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('old_preference'), isNull);
    expect(prefs.getString('testnet:accounts:activeId'), isNull);
    expect(prefs.getBool('auth:v3:guest'), isNull);
    expect(prefs.getBool('testnet:account:reconcile_pending'), isNull);
    expect(
      prefs.getInt('testnet:acct:guest:leaderboard:participant_id'),
      isNull,
    );
    expect(await const FlutterSecureStorage().readAll(), isEmpty);
    for (final directory in appDirectories.values) {
      expect(directory.listSync(), isEmpty);
    }

    expect(await RustBackendService.instance.startNode(), isFalse);
    expect(
      await platformAlarms.dispatchNativeEventForTesting(
        'android_alarm_fired',
        {
          PlatformAlarmService.applicationIncarnationKey: oldIncarnation,
        },
      ),
      isFalse,
    );
    expect(nativeEventCalls, 0);

    final coldPlatformAlarms = PlatformAlarmService.test(
      observability: ObservabilityReportingService.instance,
      platform: TargetPlatform.android,
    );
    expect(await coldPlatformAlarms.initialize(), isTrue);
    final coldIncarnation = nativeIncarnation!;
    expect(coldIncarnation, isNot(oldIncarnation));
    var coldNativeEventCalls = 0;
    coldPlatformAlarms.setNativeEventCallback((_, __) async {
      coldNativeEventCalls += 1;
      return true;
    });
    expect(
      await coldPlatformAlarms.dispatchNativeEventForTesting(
        'android_alarm_fired',
        {
          PlatformAlarmService.applicationIncarnationKey: oldIncarnation,
        },
      ),
      isFalse,
    );
    expect(
      await coldPlatformAlarms.dispatchNativeEventForTesting(
        'android_alarm_fired',
        {
          PlatformAlarmService.applicationIncarnationKey: coldIncarnation,
        },
      ),
      isTrue,
    );
    expect(coldNativeEventCalls, 1);

    final coldController = _controller(
      authority: ScriptedSessionAuthority([
        sessionAuthorityResponse(
          sequence: 0,
          state: loggedOutAuthorityState(),
          outcome: 'record_read',
        ),
      ]),
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('Cold launch unexpectedly requested another reset: $reason');
      },
    );
    addTearDown(coldController.dispose);
    await coldController.restore();
    expect(coldController.state.phase, IdentityPhase.unauthenticated);
    expect(coldController.state.participantId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('network termination keeps durable application data', () async {
    resetService.registerTerminalResetHandler((_) {});
    addTearDown(resetService.unregisterTerminalResetHandler);
    nativeCalls.clear();

    await resetService.terminatePreservingData(reason: 'network_change');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('old_preference'), 'must disappear');
    expect(prefs.getString('testnet:accounts:activeId'), 'old-account');
    expect(
      await const FlutterSecureStorage().read(key: 'old_secret'),
      'must disappear',
    );
    for (final directory in appDirectories.values) {
      expect(await File('${directory.path}/old-data').readAsString(), 'old');
      expect(
        await File('${directory.path}/nested/old-data').readAsString(),
        'old',
      );
    }
    expect(nativeCalls.last.method, 'enterTerminalReset');
    expect(nativeCalls.last.arguments, {'clearApplicationData': false});
  });

  testWidgets('signing out keeps the incarnation alive and running',
      (tester) async {
    final graphProbe = _ResetGraphProbe();
    final container = ProviderContainer(overrides: [
      _resetProbeProvider.overrideWithValue(graphProbe),
    ]);
    await tester.pumpWidget(AppRuntimeRoot(
      initialContainer: container,
      resetService: resetService,
      child: const _ResetGraphView(),
    ));
    await tester.pump(const Duration(seconds: 3));

    final oldIncarnation = nativeIncarnation!;
    nativeCalls.clear();

    var clearedWebSessions = 0;
    var clearedNotifications = 0;
    final signOutFence = InMemorySignOutFence();
    final controller = _controller(
      authority: activationSessionAuthority(
        accountId: 'account-a',
        address: 'address-a',
        userNamespace: 'aaaaaaaaaaaaaaa2',
        trailingResponses: successfulRetirementResponses(),
      ),
      clearWebSessionData: () async {
        clearedWebSessions += 1;
        return true;
      },
      signOutFence: signOutFence,
      rotateNativeGeneration: platformAlarms.rotateApplicationIncarnation,
      clearSessionNotifications: () async {
        clearedNotifications += 1;
        return platformAlarms.clearSessionNotifications();
      },
      terminalReset: ({required reason, prepareNextLaunch}) async {
        fail('A voluntary sign-out must not reset the app: $reason');
      },
    );
    addTearDown(controller.dispose);
    await controller.restore();

    expect(
      await tester.runAsync(
        () => controller.completeLogin(
          const AuthSession(
            token: 'new-session',
            participant: Participant(
              id: 2,
              email: 'two@example.com',
              emailConfirmed: true,
              identityHash: 'aaaaaaaaaaaaaaa2',
            ),
          ),
        ),
      ),
      isTrue,
    );
    await tester.pump();

    expect(
      await controller.reconcileSucceeded(
        epoch: controller.state.epoch,
        accountId: 'account-a',
        address: 'address-a',
        participantId: 2,
        provisionedSeasonId: 1,
      ),
      isTrue,
    );
    final identityBeforeLogout = controller.state;

    final signedOut = await tester.runAsync(
      () => controller.logout(expectedIdentity: controller.state),
    );
    await tester.pump();

    expect(signedOut, isTrue);
    expect(controller.state.phase, IdentityPhase.unauthenticated);
    expect(clearedWebSessions, 1);
    expect(clearedNotifications, 1);
    expect(
      signOutFence.raised,
      isFalse,
      reason: 'the crash fence is lowered once the boundary settles',
    );
    expect(signOutFence.raiseCount, 1);

    // The runtime is untouched: same provider graph, same services, same
    // native incarnation. That is the whole difference from a terminal reset —
    // iOS cannot restart the process, so the app has to survive its own
    // sign-out.
    expect(find.text('functional graph'), findsOneWidget);
    expect(graphProbe.mounted, isTrue);
    expect(graphProbe.mountCount, 1);
    expect(SentryUtil.enabled, isTrue);
    expect(AppLifecycleLogger.isRegistered, isTrue);
    expect(nativeCalls.map((call) => call.method),
        isNot(contains('enterTerminalReset')));
    expect(nativeCalls.map((call) => call.method),
        isNot(contains('invalidateApplicationIncarnation')));

    // The native generation IS retired, reversibly: durable work scheduled by
    // the signed-out session (alarms, the watchdog, headless recovery) no
    // longer matches, while this surviving process keeps scheduling under the
    // successor token.
    final rotatedIncarnation = nativeIncarnation!;
    expect(rotatedIncarnation, isNot(oldIncarnation));
    var acceptedEvents = 0;
    platformAlarms.setNativeEventCallback((_, __) async {
      acceptedEvents += 1;
      return true;
    });
    expect(
      await platformAlarms.dispatchNativeEventForTesting(
        'android_alarm_fired',
        {PlatformAlarmService.applicationIncarnationKey: oldIncarnation},
      ),
      isFalse,
      reason: 'an alarm armed by the signed-out session must not be admitted',
    );
    expect(acceptedEvents, 0);
    expect(
      await platformAlarms.dispatchNativeEventForTesting(
        'android_alarm_fired',
        {PlatformAlarmService.applicationIncarnationKey: rotatedIncarnation},
      ),
      isTrue,
      reason: 'the surviving process may still schedule and be woken',
    );
    expect(acceptedEvents, 1);

    // Unrelated local state survives; the credential does not.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('old_preference'), 'must disappear',
        reason: 'only a terminal reset erases the seeded value');
    expect(
      await AuthTokenStore().readForIdentity(identityBeforeLogout),
      isNull,
    );
    expect(
      await const FlutterSecureStorage().read(key: 'old_secret'),
      'must disappear',
    );
    for (final directory in appDirectories.values) {
      expect(directory.listSync(), isNotEmpty);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ResetGraphView extends ConsumerWidget {
  const _ResetGraphView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(_mountedResetProbeProvider);
    return const MaterialApp(home: Text('functional graph'));
  }
}

class _ResetGraphProbe {
  bool mounted = false;
  int mountCount = 0;

  void mount() {
    mounted = true;
    mountCount += 1;
  }

  void dispose() {
    mounted = false;
  }
}
