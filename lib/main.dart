import 'dart:async';
import 'dart:io' show Platform;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/data/slot_production_repository.dart';
import 'package:crypto_mobile_app/core/identity/session_controller.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/block_production_alarm_audit_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/epoch_slot_scheduler_service.dart';
import 'package:crypto_mobile_app/core/services/node_lifecycle_coordinator.dart';
import 'package:crypto_mobile_app/core/services/observability_reporting_service.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/session_runtime_boundary.dart';
import 'package:crypto_mobile_app/core/services/slot_monitor_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/features/auth/providers/post_sign_in_sync.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/onboarding/data/node_account_provisioning.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_binding.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_service.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';

Timer? _headlessProducedBlocksRefreshTimer;

/// Marionette MCP mode initializes MarionetteBinding for runtime inspection
/// and screenshots by an external AI agent. It must bypass Sentry because
/// Flutter allows only one WidgetsBinding per process.
const bool _marionetteEnabled = bool.fromEnvironment('MARIONETTE');

Future<void> main() async {
  if (_marionetteEnabled && kDebugMode) {
    MarionetteBinding.ensureInitialized();
    await _runAppBody(logTag: 'usernode/MarionetteBootstrap');
    return;
  }

  // NOTE: Do NOT call WidgetsFlutterBinding.ensureInitialized() here.
  // SentryFlutter.init() will initialize SentryWidgetsFlutterBinding which
  // is required for FramesTrackingIntegration to work properly.
  await SentryUtil.bootstrap(
    () => _runAppBody(logTag: 'usernode/Bootstrap'),
  );
}

Future<void> _runAppBody({required String logTag}) async {
  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Start terminated-app tap capture before the replaceable ProviderContainer
  // and WebView runtime are constructed. The durable pending-tap state is
  // replayed when the trusted page is ready, so native Firebase calls must not
  // delay the first frame.
  unawaited(
    SocialPushService.instance.initialize().catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint(
          '[SocialPush] Initialization failed: $error\n$stackTrace',
        );
      },
    ),
  );
  AppResetService.instance.registerPersistentResetHandler(
    SocialPushService.instance.resetForAppReset,
  );

  final boot = await AppBootstrap.initNonUi(logTag: logTag);
  final log = boot.log;

  log.info('App started');
  log.info(
    'Version check: enabled=${AppConfig.versionCheckEnabled}, host=${AppConfig.versionCheckHost}, intervalSec=${AppConfig.versionCheckIntervalSeconds}',
  );

  // Render UI immediately; perform heavy bootstrap asynchronously.
  log.info('Running app UI');
  runApp(AppRuntimeRoot(
    initialContainer: boot.container,
    initialBackendBootstrap: boot.backendBootstrap,
  ));
}

/// Headless entrypoint for background Flutter engine
/// This is used when the app runs without UI (e.g., background services)
///
/// This function is called from native code via DartExecutor.DartEntrypoint
/// with entrypoint name "headlessMain"
@pragma('vm:entry-point')
Future<void> headlessMain() async {
  // Initialize Flutter binding manually (no Sentry in headless mode)
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppSleepStateStore.load();
    await PlatformAlarmService.instance.initialize();
    final nativeWakelockHeld =
        await PlatformAlarmService.instance.isWakelockHeld();
    final watchdogDeliveryInProgress =
        await PlatformAlarmService.instance.isAlarmWatchdogDeliveryInProgress();
    if (AppSleepStateStore.isSleeping &&
        !nativeWakelockHeld &&
        !watchdogDeliveryInProgress) {
      await LoggingService.initialize();
      final log = LoggingService.instance.withTag('usernode/HeadlessBootstrap');
      log.info('Skipping headless bootstrap while app sleep is active');
      return;
    }

    final boot = await AppBootstrap.initNonUi(
      logTag: 'usernode/HeadlessBootstrap',
      registerLifecycleObserver: false,
    );
    final log = boot.log;
    final container = boot.container;

    log.debug('hasAnyAccounts: ${boot.hasAnyAccounts}');

    log.debug('Starting headless bootstrap');

    try {
      // Start headless services
      log.debug('Starting headless services...');
      await _startHeadlessServices(container, log);
      log.debug('Headless services started');
    } catch (e, st) {
      log.error(
        'Error during headless bootstrap: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  } catch (e, st) {
    // Try to initialize logging if it's not already initialized
    try {
      await LoggingService.initialize();
      final log = LoggingService.instance.withTag('usernode/HeadlessBootstrap');
      log.error('Fatal error in headless main()', error: e, stackTrace: st);
    } catch (_) {
      // If logging fails, at least we have the print statements
    }

    // Re-throw to let Flutter handle it
    rethrow;
  }
}

/// Start services that are normally started by providers in headless mode
Future<void> _startHeadlessServices(
  ProviderContainer container,
  TaggedLogger log,
) async {
  try {
    log.info(
        'Starting headless services (produced-blocks refresh, lifecycle, etc.)');

    _startHeadlessProducedBlocksRefresh(container, log);

    // Initialize backend lifecycle provider manually
    container.read(backendLifecycleProvider);

    if (Platform.isAndroid) {
      BlockProductionAlarmAuditService.instance.auditBestEffort(
        reason: 'headless_start',
      );
    }

    log.info('Headless services started successfully');
  } catch (e, st) {
    log.error('Error starting headless services: $e', error: e, stackTrace: st);
    await SentryUtil.captureError(e, st, tag: 'headless_services');
  }
}

void _startHeadlessProducedBlocksRefresh(
  ProviderContainer container,
  TaggedLogger log,
) {
  // IMPORTANT:
  // - `invalidate(producedBlocksSummaryProvider)` alone does not recompute unless something
  //   reads the provider again.
  // - In headless/background mode we proactively `refresh(...future)` on a timer so the
  //   provider's cached value stays current even without UI screens.

  _headlessProducedBlocksRefreshTimer?.cancel();

  final interval = AppConfig.headlessRefreshInterval;
  log.debug(
    'Starting headless produced blocks refresh timer',
    context: {'interval': interval.toString()},
  );

  void refreshOnce() {
    if (!RustBackendService.instance.isRunning) return;
    unawaited(() async {
      try {
        await container.refresh(producedBlocksSummaryProvider.future);
      } catch (e) {
        log.debug('Produced blocks refresh failed: $e');
      }
    }());
  }

  // Prime immediately, then keep it fresh.
  refreshOnce();
  _headlessProducedBlocksRefreshTimer = Timer.periodic(interval, (_) {
    refreshOnce();
  });
}

typedef RuntimeBootstrapFactory = Future<ProviderContainer> Function();

class AppRuntimeRoot extends StatefulWidget {
  const AppRuntimeRoot({
    super.key,
    required this.initialContainer,
    this.initialBackendBootstrap,
    this.replacementFactory,
    this.shutdownRuntime,
    this.child = const CryptoMobileApp(),
  });

  final ProviderContainer initialContainer;
  final Future<void>? initialBackendBootstrap;
  final RuntimeBootstrapFactory? replacementFactory;
  final Future<void> Function()? shutdownRuntime;
  final Widget child;

  @override
  State<AppRuntimeRoot> createState() => _AppRuntimeRootState();
}

class _AppRuntimeRootState extends State<AppRuntimeRoot> {
  ProviderContainer? _container;
  Object? _restartError;
  late Future<void> _backendBootstrap;

  @override
  void initState() {
    super.initState();
    _container = widget.initialContainer;
    _backendBootstrap = widget.initialBackendBootstrap ?? Future<void>.value();
    AppResetService.instance.registerInProcessRestartHandler(_restartInProcess);
    SessionRuntimeBoundary.instance.register(_replaceSessionRuntime);
  }

  @override
  void dispose() {
    AppResetService.instance.unregisterInProcessRestartHandler();
    SessionRuntimeBoundary.instance.unregister();
    _container?.dispose();
    super.dispose();
  }

  Future<void> _restartInProcess() async {
    final boot = await AppBootstrap.initNonUi(
      logTag: 'usernode/BootstrapRestart',
      installErrorHandlers: false,
    );

    if (!mounted) {
      boot.container.dispose();
      return;
    }

    final oldContainer = _container;
    setState(() {
      _container = boot.container;
      _backendBootstrap = boot.backendBootstrap;
      _restartError = null;
    });
    oldContainer?.dispose();
  }

  Future<void> _replaceSessionRuntime(
    SessionRuntimeChange change,
    Future<void> Function() persistSession,
  ) async {
    if (AppResetService.instance.isResetInProgress) {
      throw StateError('Cannot change sessions while app reset is in progress');
    }

    final oldContainer = _container;
    if (oldContainer == null) {
      throw StateError('There is no app runtime to replace');
    }
    final oldBackendBootstrap = _backendBootstrap;
    if (oldContainer.exists(identityProvider)) {
      oldContainer.read(identityProvider.notifier).retireForRuntimeRestart();
    }

    AppLifecycleLogger.onForegroundResume = null;
    if (mounted) {
      setState(() {
        _container = null;
        _restartError = null;
      });
    }

    var oldDisposed = false;
    try {
      // Finish any bootstrap work before stopping global services. This keeps
      // cleanup strictly sequential and avoids a start racing the hard stop.
      await _shutdownRuntime(
        oldBackendBootstrap,
        container: oldContainer,
        reason: 'session_${change.name}',
      );
      if (mounted) await WidgetsBinding.instance.endOfFrame;
      oldContainer.dispose();
      oldDisposed = true;

      await persistSession();
      if (!mounted) return;

      final replacement = await _createReplacementRuntime();
      if (!mounted) {
        replacement.dispose();
        return;
      }

      setState(() {
        _container = replacement;
        _backendBootstrap = Future<void>.value();
        _restartError = null;
      });
      LoggingService.instance.info(
        'App runtime replaced after ${change.name}',
      );
    } catch (error, stackTrace) {
      if (!oldDisposed) oldContainer.dispose();
      LoggingService.instance.error(
        'App runtime replacement failed after ${change.name}',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _restartError = error);
      rethrow;
    }
  }

  Future<void> _shutdownRuntime(
    Future<void> backendBootstrap, {
    required ProviderContainer container,
    required String reason,
  }) async {
    await backendBootstrap;
    await container.read(nodeAccountReconcilerProvider).drain();
    if (widget.shutdownRuntime != null) {
      await widget.shutdownRuntime!.call();
      return;
    }

    await NodeLifecycleCoordinator.instance
        .hardStopForSessionBoundary(reason: reason);
    AppLifecycleLogger.unregister();
    await AppSleepService.instance.stopForRuntimeRestart();
    await SlotMonitorService.instance.stopMonitoring();
    await ObservabilityReportingService.instance
        .stopMobileContextSnapshotReporting();
    EpochSlotSchedulerService.instance.dispose();
    await AndroidForegroundTaskController.instance.resetForAppRestart();
    await RustBackendService.instance.resetForAppRestart();
    SlotProductionRepository.instance.resetForAppRestart();
    PlatformAlarmService.instance.resetForAppRestart();
    MetricsCollectorService.instance.reset();
  }

  Future<ProviderContainer> _createReplacementRuntime() async {
    NodeLifecycleCoordinator.instance.resumeAfterSessionBoundary();
    final factory = widget.replacementFactory;
    if (factory != null) return factory();

    final boot = await AppBootstrap.initNonUi(
      logTag: 'usernode/SessionRestart',
      installErrorHandlers: false,
      applyBootstrapIdentity: false,
    );
    await boot.backendBootstrap;
    return boot.container;
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: _restartError == null
                ? const CircularProgressIndicator()
                : const Text(
                    'Could not restart the app. Please close and reopen it.',
                    textAlign: TextAlign.center,
                  ),
          ),
        ),
      );
    }
    return UncontrolledProviderScope(
      container: container,
      child: widget.child,
    );
  }
}

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key});

  static final _lightTheme =
      ColorIsExpensiveTheme(ThemeData.light().textTheme).light().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.light(),
            ),
          );

  static final _darkTheme =
      ColorIsExpensiveTheme(ThemeData.dark().textTheme).dark().copyWith(
            extensions: DesignSystemTheme.standardExtensions(
              semanticColors: AppSemanticColors.dark(),
            ),
          );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize backend lifecycle manager
    ref.watch(backendLifecycleProvider);

    // Initialize zkPassport pipeline state early so session-server polling
    // and foreground recovery are active before the registration UI opens.
    ref.watch(zkPassportPipelineProvider);

    // Keep the identity driver alive for the whole app lifetime: it runs
    // the account reconcile whenever the identity enters the reconciling
    // phase and retries pending zk completions once it settles.
    ref.watch(identityDriverProvider);

    // Hand the authoritative active season to the SessionController — a
    // rollover re-enters the reconciling phase (per-season wallets), and no
    // sign-in transition fires for users who stay signed in across it.
    ref.watch(seasonRolloverSyncProvider);

    // Feed the process-lifetime push service only the current ready identity
    // and exact bearer. Replacing this container replaces the adapter, not the
    // Firebase listeners or durable pending tap.
    ref.watch(socialPushBindingProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false, // Flip to true to verify 8pt grid alignment
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _AppWrapper(child: child),
    );
  }
}

/// Wrapper that handles version check and hot reload invalidation
class _AppWrapper extends ConsumerStatefulWidget {
  const _AppWrapper({required this.child});
  final Widget? child;

  @override
  ConsumerState<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<_AppWrapper>
    with WidgetsBindingObserver {
  bool _versionCheckShown = false;
  bool _wasSleeping = false;
  final _appSleepService = AppSleepService.instance;
  StreamSubscription<void>? _socialPushTapSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasSleeping = _appSleepService.isSleeping;
    _appSleepService.addListener(_handleAppSleepChanged);
    _socialPushTapSubscription =
        SocialPushService.instance.tapEvents.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openPendingSocialNotification();
      });
    });
    _syncVersionChecks();
    // Check version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialVersion();
      _openPendingSocialNotification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SocialPushService.instance.reconcileBestEffort();
      _openPendingSocialNotification();
      unawaited(
        ref.read(identityDriverProvider).refreshNow(),
      );
      // Don't reset _versionCheckShown — the guard in _checkInitialVersion
      // prevents stacking a second dialog on top of an already-shown one.
      ref.invalidate(appVersionCheckProvider);
      _checkInitialVersion();
    }
  }

  Future<void> _checkInitialVersion() async {
    final log = LoggingService.instance.withTag('usernode/VersionCheck');
    log.info('_checkInitialVersion called');
    try {
      final result = await ref.read(appVersionCheckProvider.future);
      log.info(
        'Version check result: $result, shouldShow: ${result?.shouldShowDialog}, shown: $_versionCheckShown, mounted: $mounted',
      );
      if (result != null &&
          result.shouldShowDialog &&
          !_versionCheckShown &&
          mounted) {
        _versionCheckShown = true;
        log.info('Showing update dialog...');
        showUpdateDialog(appNavigatorKey, result);
      }
    } catch (e) {
      log.error('Error in _checkInitialVersion: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appSleepService.removeListener(_handleAppSleepChanged);
    unawaited(_socialPushTapSubscription?.cancel());
    AppVersionCheck.instance.stopPeriodicChecks();
    super.dispose();
  }

  void _openPendingSocialNotification() {
    if (!mounted || !SocialPushService.instance.hasPendingTap) return;
    ref.read(appRouterProvider).go(AppRoutes.home);
  }

  void _handleVersionCheckResult(VersionCheckResult result) {
    if (!mounted || _versionCheckShown) return;
    _versionCheckShown = true;
    showUpdateDialog(appNavigatorKey, result);
  }

  void _handleAppSleepChanged() {
    final isSleeping = _appSleepService.isSleeping;
    _syncVersionChecks();
    if (_wasSleeping && !isSleeping) {
      // Sleep only pauses the node; the UI never went away, so there is no
      // post-wake navigation reset — just refresh the node-backed data.
      unawaited(_refreshWakeData());
    }
    _wasSleeping = isSleeping;
  }

  Future<void> _refreshWakeData() async {
    final log = LoggingService.instance.withTag('usernode/AppWakeRefresh');

    if (Platform.isAndroid) {
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (DateTime.now().isBefore(deadline) &&
          !RustBackendService.instance.isRunning) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    Future<void> guardedRefresh(
      String label,
      Future<void> Function() refresh,
    ) async {
      try {
        await refresh();
      } catch (e) {
        log.warn('Wake refresh failed for $label: $e');
      }
    }

    await guardedRefresh(
      'node_status',
      () => ref.read(nodeStatusProvider.notifier).refresh(),
    );
    await guardedRefresh(
      'node_blockchain',
      () => ref.read(nodeBlockchainProvider.notifier).refresh(),
    );
    await guardedRefresh(
      'epoch_rewards',
      () => ref.read(epochRewardsProvider.notifier).refresh(),
    );
    await guardedRefresh(
      'produced_blocks_summary',
      () => ref.refresh(producedBlocksSummaryProvider.future),
    );
  }

  void _syncVersionChecks() {
    if (_appSleepService.isSleeping) {
      AppVersionCheck.instance.stopPeriodicChecks();
      return;
    }

    AppVersionCheck.instance.startPeriodicChecks(_handleVersionCheckResult);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Invalidate only the produced blocks summary provider on hot reload.
    ref.invalidate(producedBlocksSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_down');
      },
      onPointerMove: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_move');
      },
      onPointerSignal: (_) {
        _appSleepService.recordUserInteraction(source: 'pointer_signal');
      },
      // App sleep only pauses the node — the UI stays live and interactive,
      // so no sleep overlay or ticker freeze here. The pointer listeners
      // above double as the wake gesture (see
      // AppSleepService.recordUserInteraction).
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child ?? const SizedBox.shrink(),
          const ClockDriftWarningOverlay(),
        ],
      ),
    );
  }
}
