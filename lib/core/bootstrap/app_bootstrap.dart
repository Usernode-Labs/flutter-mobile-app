import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_bootstrap.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/slot_monitor_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
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

    if (installErrorHandlers) {
      _installGlobalErrorHandlers(log);
    }

    // Initialize platform alarm service early to capture native events
    await PlatformAlarmService.instance.initialize();
    PlatformAlarmService.instance.setNativeEventCallback(
      (eventType, eventData) {
        AppSleepService.instance.handleNativeEvent(eventType, eventData);
        AndroidForegroundTaskController.instance.handleNativeEvent(
          eventType,
          eventData,
        );
        // Per-slot alarm fires arrive here as android_alarm_fired with
        // alarmId=`slot_<N>`. Drive SlotMonitorService from those so the
        // recorder pipeline (slot_outcome_reports) actually runs.
        unawaited(_routeAlarmToSlotMonitor(eventType, eventData));
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
    final hasAnyAccounts = await repo.hasAny();
    final activeId = repo.getActiveId();

    if (activeId != null && SentryUtil.enabled) {
      await SentryUtil.setUser(id: activeId);
      log.debug('Set Sentry user context for existing account: $activeId');
    }

    // Metrics collector needs the container before any lifecycle/service starts
    MetricsCollectorService.instance.initialize(container);

    // Load persisted scheduled slots so the alarm-fired callback below can
    // resolve a slotNumber back to its full ScheduledSlot (including epoch +
    // alarmTime), and start the SlotMonitorService so its foreground
    // auto-start ticker is ready. Both are best-effort: scheduler.initialize
    // also runs an RPC call that is allowed to fail at boot.
    try {
      await EpochSlotSchedulerService.instance.initialize();
    } catch (e) {
      log.warn(
        'EpochSlotSchedulerService.initialize failed at bootstrap: $e',
      );
    }
    try {
      await SlotMonitorService.instance.initialize();
    } catch (e) {
      log.warn(
        'SlotMonitorService.initialize failed at bootstrap: $e',
      );
    }

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
      AppLifecycleLogger.onForegroundResume = recoverZkSession;
    }

    _bootstrapBackendAsync(log: log, container: container);

    return AppBootstrapResult(
      container: container,
      log: log,
      hasAnyAccounts: hasAnyAccounts,
      activeAccountId: activeId,
    );
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

      // Initialize FRB only; start backend only if an account exists
      if (!RustBackendService.instance.isRunning) {
        log.info('Backend not running, initializing...');
        await RustBackendService.instance.init();
        log.info('FRB initialized, starting node...');
        final started = await RustBackendService.instance.startNode();
        log.info(
            'Backend startNode => $started, isRunning=${RustBackendService.instance.isRunning}');
        log.info(started
            ? 'backend startNode: started'
            : 'backend startNode: skipped');
        if (started) {
          log.info(
              'Node started successfully, waiting 1 second for node to be ready...');
          await Future.delayed(const Duration(seconds: 1));
          log.info('Node should be ready now');
        }
      } else {
        log.info('Backend already running, skipping start');
      }

      // Kick off Android foreground VRF monitoring once the node is running
      if (Platform.isAndroid) {
        log.info('Starting Android foreground VRF monitoring');
        await AndroidForegroundTaskController.instance.onNodeStarted();
      }

      log.debug('Bootstrap end');
    } catch (e, st) {
      log.error('Bootstrap failed: $e', error: e, stackTrace: st);
      await SentryUtil.captureError(e, st, tag: 'bootstrap');
    }
  }

  /// Translate per-slot `android_alarm_fired` callbacks into
  /// [SlotMonitorService.startMonitoringSlot] calls so the recorder produces
  /// a [SlotOutcomeReport] for each won slot. No-op for non-slot alarms
  /// (e.g. `fg_resume`, which `AndroidForegroundTaskController` already owns).
  static Future<void> _routeAlarmToSlotMonitor(
    String eventType,
    Map<String, dynamic> eventData,
  ) async {
    if (eventType != 'android_alarm_fired') return;

    final alarmId = eventData['alarmId'] as String?;
    if (alarmId == null || !alarmId.startsWith('slot_')) return;

    final slotNumber = _intFromDynamic(eventData['slotNumber']);
    if (slotNumber == null || slotNumber < 0) return;

    final log = LoggingService.instance.withTag('usernode/AppBootstrap');

    // Belt-and-suspenders: the scheduler is initialized at bootstrap, but if
    // the alarm fires before that completes (cold start race) we initialize
    // again here. Both calls are idempotent.
    try {
      await EpochSlotSchedulerService.instance.initialize();
    } catch (e) {
      log.debug('Scheduler re-init in alarm handler failed: $e');
    }
    try {
      await SlotMonitorService.instance.initialize();
    } catch (e) {
      log.debug('SlotMonitor re-init in alarm handler failed: $e');
    }

    ScheduledSlot? slot;
    for (final s in EpochSlotSchedulerService.instance.getScheduledSlots()) {
      if (s.slotNumber == slotNumber) {
        slot = s;
        break;
      }
    }

    if (slot == null) {
      log.warn(
        'Alarm fired for slot $slotNumber but no ScheduledSlot is persisted; '
        'skipping recorder hookup',
        context: {'alarm_id': alarmId},
      );
      return;
    }

    log.info(
      'Routing alarm to SlotMonitorService',
      context: {
        'slot_number': slotNumber,
        'epoch': slot.epoch,
        'alarm_id': alarmId,
      },
    );

    try {
      await SlotMonitorService.instance.startMonitoringSlot(slot);
    } catch (e, st) {
      log.error(
        'SlotMonitorService.startMonitoringSlot failed for slot $slotNumber: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  static int? _intFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
