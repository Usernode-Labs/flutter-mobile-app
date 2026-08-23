import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_namespace_store.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/identity/session_retirement_repair.dart';
import 'package:crypto_mobile_app/core/identity/sign_out_fence.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

/// Runs the one-time authority cleanup only while the Rust journal is absent.
/// Journal absence remains the retry marker after a crash or failed cleanup.
Future<void> runPreJournalBootstrap({
  required bool journalMissing,
  required List<Future<bool> Function()> cleanupSteps,
  required Future<void> Function() createLoggedOut,
}) async {
  if (!journalMissing) return;
  for (var index = 0; index < cleanupSteps.length; index++) {
    if (!await cleanupSteps[index]()) {
      throw StateError('Pre-journal cleanup $index was not confirmed');
    }
  }
  await createLoggedOut();
}

class AppBootstrapResult {
  final ProviderContainer container;
  final TaggedLogger log;
  final bool hasAnyAccounts;
  final String? activeAccountId;
  final Future<void> backendBootstrap;

  const AppBootstrapResult({
    required this.container,
    required this.log,
    required this.hasAnyAccounts,
    required this.activeAccountId,
    required this.backendBootstrap,
  });
}

/// Shared, non-UI app initialization used by both `main.dart` and
/// `main_headless.dart`.
///
/// Assumes a Flutter binding exists. For the UI entrypoint, call this inside
/// `SentryUtil.bootstrap(...)`. For headless entrypoints, call
/// `WidgetsFlutterBinding.ensureInitialized()` before invoking this.
class AppBootstrap {
  static Future<AppBootstrapResult> initNonUi({
    required String logTag,
    bool registerLifecycleObserver = true,
    bool installErrorHandlers = true,
    bool applyBootstrapIdentity = true,
  }) async {
    // Initialize network preferences early (before any SharedPreferences access)
    await NetworkPrefs.init();

    // Initialize logging with file output
    await LoggingService.initialize();
    final log = LoggingService.instance.withTag(logTag);

    // Load the Debug Mode flag into its synchronous cache so the HTTP layer
    // sees the correct value before the first request.
    await DebugModeStorage.init();

    if (installErrorHandlers) {
      _installGlobalErrorHandlers(log);
    }

    // Must settle before native scheduling can mint legacy admission and
    // before any provider can instantiate a session-owned surface.
    final sessionAuthority = await _ensureSessionAuthorityJournal(log);

    // Initialize platform alarm service early to capture native events
    await PlatformAlarmService.instance.initialize();
    PlatformAlarmService.instance.setNativeEventCallback(
      (eventType, eventData) async {
        if (eventType == 'android_alarm_recovery_requested') {
          log.warn(
            'Native alarm recovery event delivered',
            context: eventData,
          );
        }
        _dispatchNativeEvent(
          log: log,
          handlerName: 'app_sleep',
          eventType: eventType,
          eventData: eventData,
          handler: () =>
              AppSleepService.instance.handleNativeEvent(eventType, eventData),
        );
        _dispatchNativeEvent(
          log: log,
          handlerName: 'android_foreground_task',
          eventType: eventType,
          eventData: eventData,
          handler: () => AndroidForegroundTaskController.instance
              .handleNativeEvent(eventType, eventData),
        );
        try {
          return await BlockProductionAlarmAuditService.instance
              .handleNativeEvent(eventType, eventData);
        } catch (e, st) {
          log.warn(
            'Native event handler failed',
            context: {
              'handler': 'alarm_audit',
              'event_type': eventType,
              'error': e,
              ...eventData,
            },
          );
          log.debug('$st');
          return false;
        }
      },
    );

    // Create provider container
    final container = ProviderContainer(overrides: [
      sessionAuthorityGatewayProvider.overrideWithValue(sessionAuthority),
    ]);

    // Restore the identity (and with it the active per-identity storage
    // bucket) before any account-scoped pref is read. This publishes the
    // boot identity: unauthenticated, guest, ready, or reconciling when a
    // sign-in's account reconcile was interrupted — in which case the node
    // start below is refused until the reconcile completes.
    await container.read(identityProvider.notifier).restore();
    final identity = container.read(identityProvider);
    final repo = await AccountsRepository.create();
    if (applyBootstrapIdentity) {
      await _applyBootstrapIdentity(
        log: log,
        container: container,
        repo: repo,
        identity: identity,
      );
    }
    var hasAnyAccounts = false;
    String? activeId;
    if (identity.phase == IdentityPhase.ready) {
      hasAnyAccounts = await repo.hasAny();
      activeId = repo.getActiveId();
    }

    if (activeId != null && SentryUtil.enabled) {
      await SentryUtil.setUser(id: activeId);
      log.debug('Set Sentry user context for existing account: $activeId');
    }

    // Metrics collector needs the container before any lifecycle/service starts
    MetricsCollectorService.instance.initialize(container);
    ObservabilityReportingService.instance.configureMobileContextCollector(
      MetricsCollectorService.instance,
    );
    ObservabilityReportingService.instance.configureNodeRuntimeActiveGetter(
      () => RustBackendService.instance.isRuntimeActive,
    );

    if (registerLifecycleObserver) {
      await AppSleepService.instance.initializeForInteractiveApp();
    }

    void recoverZkSession() {
      container
          .read(zkPassportPipelineProvider.notifier)
          .recoverPendingSessionOnForeground();
    }

    if (registerLifecycleObserver) {
      AppLifecycleLogger.register();
      AppLifecycleLogger.onForegroundResume = () {
        recoverZkSession();
        BlockProductionAlarmAuditService.instance.auditBestEffort(
          reason: 'foreground_resume',
        );
      };
    }

    final backendBootstrap = _bootstrapBackendAsync(
      log: log,
      container: container,
    );

    return AppBootstrapResult(
      container: container,
      log: log,
      hasAnyAccounts: hasAnyAccounts,
      activeAccountId: activeId,
      backendBootstrap: backendBootstrap,
    );
  }

  static void _dispatchNativeEvent({
    required TaggedLogger log,
    required String handlerName,
    required String eventType,
    required Map<String, dynamic> eventData,
    required void Function() handler,
  }) {
    try {
      handler();
    } catch (e, st) {
      log.warn(
        'Native event handler failed',
        context: {
          'handler': handlerName,
          'event_type': eventType,
          'error': e,
          ...eventData,
        },
      );
      log.debug('$st');
    }
  }

  static Future<SessionAuthorityGateway> _ensureSessionAuthorityJournal(
    TaggedLogger log,
  ) async {
    final backend = RustBackendService.instance;
    await backend.init();
    final authority = SessionAuthorityGateway();
    final admission = await authority.admission();
    final status = admission['status'];
    if (status == 'recovery_required') {
      throw StateError(
        'Session authority requires recovery: ${admission['reason']}',
      );
    }

    if (status == 'missing_journal') {
      final network = NetworkPrefs.currentNetwork;
      final sessionId = _newSessionAuthorityId();
      await runPreJournalBootstrap(
        journalMissing: true,
        cleanupSteps: [
          AuthTokenStore().clear,
          AuthGuestFlag().clear,
          clearGuestParticipantId,
          clearIdentityNamespace,
          DurableSignOutFence().lower,
          () async {
            await backend.stopNode();
            return true;
          },
          PlatformAlarmService.instance.clearLegacySessionAuthority,
          PlatformAlarmService.instance.clearWebSessionData,
        ],
        createLoggedOut: () async {
          final created = await authority.bootstrapLoggedOut(
            network: network,
            sessionId: sessionId,
          );
          if (created['status'] != 'logged_out' ||
              created['session_id'] != sessionId ||
              created['network'] != network) {
            throw StateError('Fresh LoggedOut authority was not confirmed');
          }
        },
      );
      await NetworkPrefs.adoptAuthorityNetwork(network);
      log.info('Created fresh LoggedOut authority after legacy cleanup');
      return authority;
    }

    if (status != 'logged_out' && status != 'ready' && status != 'closed') {
      throw StateError('Unknown session authority admission: $status');
    }
    final read = await authority.command({'command': 'read_record'});
    final record = _bootstrapMap(read['record'], 'record');
    final network = record['network'];
    if (network is! String || network.isEmpty) {
      throw StateError('Session authority record has no network');
    }
    await NetworkPrefs.adoptAuthorityNetwork(network);
    final state = _bootstrapMap(record['state'], 'record.state');
    if (state['kind'] == 'retiring') {
      final completed = await RetirementRepairScope(
        authority: authority,
        clearWebSessionData: PlatformAlarmService.instance.clearWebSessionData,
      ).repair(read);
      final completedRecord =
          _bootstrapMap(completed['record'], 'retirement.record');
      final completedState =
          _bootstrapMap(completedRecord['state'], 'retirement.record.state');
      if (completedState['kind'] != 'logged_out') {
        throw StateError('Interrupted retirement did not commit LoggedOut');
      }
      final successorNetwork = completedRecord['network'];
      if (successorNetwork is! String || successorNetwork.isEmpty) {
        throw StateError('LoggedOut successor has no network');
      }
      await NetworkPrefs.adoptAuthorityNetwork(successorNetwork);
      log.info('Completed interrupted retirement before provider bootstrap');
    }
    return authority;
  }

  static String _newSessionAuthorityId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return 'session-${base64Url.encode(bytes).replaceAll('=', '')}';
  }

  static Future<void> _applyBootstrapIdentity({
    required TaggedLogger log,
    required ProviderContainer container,
    required AccountsRepository repo,
    required Identity identity,
  }) async {
    final secretKey = AppConfig.bootstrapSecretKey;
    final participantId = AppConfig.bootstrapParticipantId;
    final seasonId = AppConfig.bootstrapSeasonId;
    final seasonName = AppConfig.bootstrapSeasonName.trim();
    final eventId = AppConfig.bootstrapEventId;
    final eventName = AppConfig.bootstrapEventName.trim();

    final hasBootstrapConfig = secretKey.isNotEmpty ||
        participantId != null ||
        seasonId != null ||
        seasonName.isNotEmpty ||
        eventId != null ||
        eventName.isNotEmpty;
    if (!hasBootstrapConfig) {
      return;
    }

    log.info('Applying bootstrap identity from env', context: {
      'has_secret_key': secretKey.isNotEmpty,
      'has_participant_id': participantId != null,
      'season_id': seasonId,
      'event_id': eventId,
    });

    // (Bootstrap-env onboarding completion was removed with the retired
    // native onboarding; account activation below is the only effect.)
    if (secretKey.isNotEmpty) {
      try {
        await RustBackendService.instance.init();
        final bootstrapAddress =
            accountFromPrivateKey(secretKey: secretKey).address;
        if (identity.phase != IdentityPhase.ready ||
            identity.address != bootstrapAddress) {
          throw StateError(
            'Bootstrap account does not match the restored Ready authority',
          );
        }
        final capability = repo.capabilityFor(identity);
        final account = await repo.getAuthorizedAccount(capability);
        if (account == null) {
          throw StateError('Bootstrap Ready account metadata is unavailable');
        }
        log.info(
          'Bootstrap account matches the restored Ready authority',
          context: {'account_id': account.id, 'address': account.address},
        );
      } catch (e, st) {
        log.error(
          'Bootstrap account import failed: $e',
          error: e,
          stackTrace: st,
        );
      }
    }

    if (participantId != null) {
      await saveParticipantId(participantId);
      log.info('Persisted bootstrap participant id', context: {
        'participant_id': participantId,
      });
    }

    final hasSeasonContext = seasonId != null ||
        seasonName.isNotEmpty ||
        eventId != null ||
        eventName.isNotEmpty;
    if (hasSeasonContext) {
      final ctx = SeasonEventContext(
        seasonId: seasonId,
        seasonName: seasonName.isNotEmpty ? seasonName : null,
        eventId: eventId,
        eventName: eventName.isNotEmpty ? eventName : null,
      );
      container.read(seasonEventContextProvider.notifier).state = ctx;
      await LeaderboardBootstrap.persistSeasonEvent(ctx);
      log.info('Persisted bootstrap season/event context', context: {
        'season_id': ctx.seasonId,
        'event_id': ctx.eventId,
      });
    }
  }

  static Future<void> _bootstrapBackendAsync({
    required TaggedLogger log,
    required ProviderContainer container,
  }) async {
    try {
      log.debug('Bootstrap begin');
      log.info('Initializing application');

      // Log environment/config for diagnostics
      final cfg = AppConfig.instance;
      log.debug('Environment config loaded', context: {
        'environment': cfg.environment,
        'verboseLogging': cfg.verboseLogging,
      });

      // Initialize FRB for native event delivery. The node is NOT started
      // here: node lifecycle is platform-controlled (SV chrome requests the
      // start over bridge v4 once the shell boots and the identity settles).
      // Android alarm/watchdog paths still start the node headless for block
      // production independently of this bootstrap.
      final nodeWasRunning = RustBackendService.instance.isRunning;
      if (!nodeWasRunning) {
        log.info('Backend not running, initializing...');
        await RustBackendService.instance.init();
        log.info('FRB initialized; node start deferred to the platform');
      } else {
        log.info('Backend already running, skipping start');
        await ObservabilityReportingService.instance.reportNodeInitialized(
          resetStaticContext: false,
        );
      }

      // The UI remains live while backend initialization is in flight. Read
      // identity only now so an initial login that settled meanwhile cannot be
      // overwritten by its stale boot-time eligibility.
      final currentIdentity = container.read(identityProvider);
      final producerEligible = currentIdentity.phase == IdentityPhase.ready;
      log.debug('Reporting current cold-boot eligibility', context: {
        'identity_phase': currentIdentity.phase.name,
        'producer_eligible': producerEligible,
      });

      // Report cold-boot facts to the lifecycle coordinator, which
      // reconciles the Android block-production wiring (watchdog recovery,
      // alarms, foreground service) against them. With an account and no
      // platform start request yet, recovery stays armed WITHOUT starting
      // the node: interactive boots defer the start to the platform bridge,
      // while headless recovery paths (boot receiver, WorkManager watchdog,
      // force-stop recovery) can still start it through the audit gate.
      await NodeLifecycleCoordinator.instance.reportColdBoot(
        hasAccount: producerEligible,
        reason: 'bootstrap',
      );
      // Native exact events are released only after the recovered identity has
      // either enabled signed-in producer recovery or left it closed. This
      // preserves the event that launched a headless engine without ever
      // defaulting recovery open for guest/unknown identities.
      await PlatformAlarmService.instance.markReadyForNativeEvents();
      if (Platform.isAndroid && producerEligible) {
        // Force-stop detection is bootstrap-specific: it inspects the native
        // "was force-stopped" launch flag, and on detection kicks a recovery
        // audit that may start the node headless to restore production.
        unawaited(_runStartupAlarmAudit(log));
      }

      log.debug('Bootstrap end');
    } catch (e, st) {
      log.error('Bootstrap failed: $e', error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'bootstrap');
    }
  }

  static Future<void> _runStartupAlarmAudit(TaggedLogger log) async {
    try {
      final forceStopRecovery = await BlockProductionAlarmAuditService.instance
          .auditForceStopRecoveryIfNeeded();
      if (!forceStopRecovery && RustBackendService.instance.isRunning) {
        await BlockProductionAlarmAuditService.instance.audit(
          reason: 'cold_start',
        );
      }
    } catch (e, st) {
      log.warn('Startup alarm audit failed: $e');
      log.debug('$st');
    }
  }

  static void _installGlobalErrorHandlers(TaggedLogger log) {
    // Capture build/layout framework errors.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      log.error(
        'Flutter framework error',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        context: {'library': details.library ?? 'unknown'},
      );
    };

    // Capture uncaught async errors.
    PlatformDispatcher.instance.onError = (error, stack) {
      log.error('Uncaught async error', error: error, stackTrace: stack);
      return true;
    };
  }
}

Map<String, dynamic> _bootstrapMap(Object? value, String field) {
  if (value is! Map) throw StateError('Session authority $field is not a map');
  return Map<String, dynamic>.from(value);
}
