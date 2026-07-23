import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/config/api_version_gate.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/wallet/models/account.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/src/rust/account.dart';

class AppBootstrapResult {
  final ProviderContainer container;
  final TaggedLogger log;
  final bool hasAnyAccounts;
  final String? activeAccountId;

  const AppBootstrapResult({
    required this.container,
    required this.log,
    required this.hasAnyAccounts,
    required this.activeAccountId,
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

    // Reconcile the stored api-version before ANY session-state reader can run.
    //
    // This must precede alarm initialisation and the native-event callback
    // below: a delivered alarm can enter watchdog recovery, which reaches
    // UserTypeStore via node_service, and that would otherwise observe the old
    // tier while this reconciliation was still awaiting storage.
    final versionCheck = await reconcileApiVersion();
    if (versionCheck.cleared) {
      log.info(
        'Session cleared by api-version gate (stored=${versionCheck.stored}); '
        'user will be sent to the welcome screen',
      );
    }

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
    final container = ProviderContainer();

    // Accounts are needed to decide background behavior and set crash context
    final repo = await AccountsRepository.create();
    await _applyBootstrapIdentity(
      log: log,
      container: container,
      repo: repo,
    );
    // Resolve the active per-identity storage bucket before any account-scoped
    // pref is read: a guest session gets the guest bucket, otherwise the active
    // on-chain account's bucket.
    await refreshActiveAccountBucket(guest: await UserTypeStore().isGuest());
    final hasAnyAccounts = await repo.hasAny();
    final activeId = repo.getActiveId();

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

    _bootstrapBackendAsync(
      log: log,
      container: container,
      hasAnyAccounts: hasAnyAccounts,
    );

    return AppBootstrapResult(
      container: container,
      log: log,
      hasAnyAccounts: hasAnyAccounts,
      activeAccountId: activeId,
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

  static Future<void> _applyBootstrapIdentity({
    required TaggedLogger log,
    required ProviderContainer container,
    required AccountsRepository repo,
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
      'complete_onboarding': AppConfig.bootstrapCompleteOnboarding,
    });

    var hasActiveAccount = false;
    if (secretKey.isNotEmpty) {
      try {
        await RustBackendService.instance.init();
        final bootstrapAddress =
            accountFromPrivateKey(secretKey: secretKey).address;
        AccountMeta? existingAccount;
        for (final account in await repo.list()) {
          if (account.address == bootstrapAddress) {
            existingAccount = account;
            break;
          }
        }
        if (existingAccount != null) {
          await repo.setActiveId(existingAccount.id);
          hasActiveAccount = true;
          log.info(
            'Bootstrap account already exists; reusing existing account',
            context: {
              'account_id': existingAccount.id,
              'address': existingAccount.address,
            },
          );
        } else {
          final account = await repo.importFromSecretKey(
            name: AppConfig.bootstrapAccountName,
            secretKey: secretKey,
          );
          hasActiveAccount = true;
          log.info(
            'Bootstrap account ready',
            context: {'account_id': account.id, 'address': account.address},
          );
        }
      } catch (e, st) {
        log.error(
          'Bootstrap account import failed: $e',
          error: e,
          stackTrace: st,
        );
      }
    } else {
      hasActiveAccount = await repo.hasAny();
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

    if (hasActiveAccount && AppConfig.bootstrapCompleteOnboarding) {
      await markOnboardingComplete();
      log.info('Marked onboarding complete from bootstrap env');
    }
  }

  static Future<void> _bootstrapBackendAsync({
    required TaggedLogger log,
    required ProviderContainer container,
    required bool hasAnyAccounts,
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

      // Load feature flags from assets (if provided)
      await FeatureFlags.loadFromAssetIfAvailable();
      if (kDebugMode) {
        log.debug(
          'Feature flags loaded: ${FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList()}',
        );
      }

      // Initialize FRB and start the node. startNode itself picks keyed vs
      // keyless from the tier, so guests and members get a syncing, non-
      // producing node rather than no node at all.
      final nodeWasRunning = RustBackendService.instance.isRunning;
      if (!nodeWasRunning) {
        log.info('Backend not running, initializing...');
        await RustBackendService.instance.init();
        await PlatformAlarmService.instance.markReadyForNativeEvents();
        log.info('FRB initialized, starting node...');
        final started = await RustBackendService.instance.startNode();
        log.info(
            'Backend startNode => $started, isRunning=${RustBackendService.instance.isRunning}');
        if (started) {
          log.info(
              'Node started successfully, waiting 1 second for node to be ready...');
          await Future.delayed(const Duration(seconds: 1));
          log.info('Node should be ready now');
        }
      } else {
        log.info('Backend already running, skipping start');
        await PlatformAlarmService.instance.markReadyForNativeEvents();
        await ObservabilityReportingService.instance.reportNodeInitialized(
          resetStaticContext: false,
        );
      }

      // Watchdog work is useful only while a keyed (block-producing) node is
      // actually running — a keyless guest/member node has nothing to recover.
      if (Platform.isAndroid) {
        final blockProductionActive =
            RustBackendService.instance.isBlockProducing;
        if (blockProductionActive) {
          BlockProductionAlarmAuditService.instance.enableWatchdogRecovery();
          log.info('Starting Android foreground VRF monitoring');
          await AndroidForegroundTaskController.instance.onNodeStarted();
          unawaited(_runStartupAlarmAudit(log));
        } else {
          BlockProductionAlarmAuditService.instance.disableWatchdogRecovery();
          log.info(
            'Cancelling Android alarm watchdog because block production is inactive',
            context: {
              'has_account': hasAnyAccounts,
              'node_running': RustBackendService.instance.isRunning,
            },
          );
          await PlatformAlarmService.instance.cancelAlarmWatchdog();
        }
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
