import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/services/app_reset_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_service.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/features/app_sleep/screens/app_sleep_screen.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zk_identity/providers/zk_identity_providers.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/design_system/theme/color_is_expensive_theme.dart';
import 'package:crypto_mobile_app/design_system/theme/design_system_theme.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_semantic_colors.dart';
import 'core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/core/providers/metrics_provider.dart';
import 'package:crypto_mobile_app/core/providers/node_data_providers.dart';
import 'package:crypto_mobile_app/core/providers/node_provider.dart';
import 'package:crypto_mobile_app/core/providers/epoch_rewards_provider.dart';
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
import 'package:crypto_mobile_app/core/widgets/clock_drift_warning_overlay.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

Timer? _headlessProducedBlocksRefreshTimer;

Future<void> main() async {
  // NOTE: Do NOT call WidgetsFlutterBinding.ensureInitialized() here.
  // SentryFlutter.init() will initialize SentryWidgetsFlutterBinding which
  // is required for FramesTrackingIntegration to work properly.

  await SentryUtil.bootstrap(() async {
    // Lock orientation to portrait mode
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    final boot = await AppBootstrap.initNonUi(logTag: 'usernode/Bootstrap');
    final log = boot.log;

    log.info('App started');
    log.info(
      'Version check: enabled=${AppConfig.versionCheckEnabled}, host=${AppConfig.versionCheckHost}, intervalSec=${AppConfig.versionCheckIntervalSeconds}',
    );

    // Render UI immediately; perform heavy bootstrap asynchronously.
    log.info('Running app UI');
    runApp(AppRuntimeRoot(initialContainer: boot.container));
  });
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
    if (AppSleepStateStore.isSleeping && !nativeWakelockHeld) {
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
    log.info('Starting headless services (metrics, lifecycle, etc.)');

    _startHeadlessProducedBlocksRefresh(container, log);

    // Start metrics reporting service if enabled
    if (AppConfig.metricsEnabled && AppConfig.metricsEndpoint.isNotEmpty) {
      log.info(
        'Starting metrics reporting service in headless mode',
        context: {
          'endpoint': AppConfig.metricsEndpoint,
          'interval_seconds': AppConfig.metricsCollectionIntervalSeconds,
        },
      );
      await MetricsReportingService.instance.start();
      log.info('Metrics reporting service started successfully');

      // Set wallet data callback for metrics collection
      MetricsReportingService.instance.setWalletDataCallback(() async {
        try {
          final repo = await AccountsRepository.create();
          final account = await repo.getActive();
          if (account == null || account.address.isEmpty) {
            return (balance: null, address: null);
          }

          // Only fetch UTXOs if address is in UTXO format (starts with 'ut')
          if (!account.address.startsWith('ut')) {
            log.debug(
              'Account address not in UTXO format, skipping balance calculation',
            );
            return (balance: null, address: account.address);
          }

          // Parse address to PublicKeyHash
          final owner = frb_types.publicKeyHashFromString(s: account.address);
          final utxosResp = await RustBackendService.instance.listUtxosByOwner(
            owner: owner,
          );
          final utxos = utxosResp?.items ?? [];

          // Calculate total balance by summing all UTXO amounts
          BigInt totalBalance = BigInt.zero;
          for (final ownedUtxo in utxos) {
            try {
              // Serialize UTXO to JSON to access its fields
              final jsonStr = frb_types.utxoToJson(utxo: ownedUtxo.utxo);
              final utxoData = json.decode(jsonStr) as Map<String, dynamic>;

              final rawAmount = utxoData['amount'] ?? utxoData['balance'];
              if (rawAmount is BigInt) {
                totalBalance += rawAmount;
              } else if (rawAmount is int) {
                totalBalance += BigInt.from(rawAmount);
              } else if (rawAmount is num) {
                totalBalance += BigInt.from(rawAmount.toInt());
              } else if (rawAmount is String) {
                final parsed = BigInt.tryParse(rawAmount);
                if (parsed != null) {
                  totalBalance += parsed;
                }
              }
            } catch (e) {
              // Skip this UTXO if parsing fails
              log.warn('Error parsing UTXO for balance: $e');
            }
          }

          return (balance: totalBalance, address: account.address);
        } catch (e) {
          log.warn('Error fetching wallet data for metrics: $e');
          return (balance: null, address: null);
        }
      });
    } else {
      log.debug('Metrics disabled or not configured in headless mode');
    }

    // Initialize backend lifecycle provider manually
    container.read(backendLifecycleProvider);

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

  final interval = AppConfig.metricsCollectionInterval;
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

class AppRuntimeRoot extends StatefulWidget {
  const AppRuntimeRoot({super.key, required this.initialContainer});

  final ProviderContainer initialContainer;

  @override
  State<AppRuntimeRoot> createState() => _AppRuntimeRootState();
}

class _AppRuntimeRootState extends State<AppRuntimeRoot> {
  late ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = widget.initialContainer;
    AppResetService.instance.registerInProcessRestartHandler(_restartInProcess);
  }

  @override
  void dispose() {
    AppResetService.instance.unregisterInProcessRestartHandler();
    _container.dispose();
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
    });
    oldContainer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: _container,
      child: const CryptoMobileApp(),
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

    // Initialize metrics lifecycle manager
    ref.watch(metricsLifecycleProvider);

    // Initialize zkPassport pipeline state early so session-server polling
    // and foreground recovery are active before the registration UI opens.
    ref.watch(zkPassportPipelineProvider);

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
  final _wakeLog = LoggingService.instance.withTag('usernode/AppWakeRoute');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasSleeping = _appSleepService.isSleeping;
    _appSleepService.addListener(_handleAppSleepChanged);
    _syncVersionChecks();
    // Check version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialVersion());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
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
    AppVersionCheck.instance.stopPeriodicChecks();
    super.dispose();
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
      unawaited(_refreshWakeData());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final zkIdentityChallengeActive =
            ref.read(zkIdentityChallengeActiveProvider);
        final zkPassportPipeline = ref.read(zkPassportPipelineProvider);
        final shouldPreserveCurrentRoute = zkIdentityChallengeActive ||
            zkPassportPipeline.status == ZkPassportPipelineStatus.processing;
        _wakeLog.warn('Handling app wake route decision', context: {
          'zkIdentityChallengeActive': zkIdentityChallengeActive,
          'pipelineStatus': zkPassportPipeline.status.name,
          'pipelinePhase': zkPassportPipeline.phase.name,
          'pipelineRequestId': zkPassportPipeline.requestId,
          'preserveCurrentRoute': shouldPreserveCurrentRoute,
        });
        if (shouldPreserveCurrentRoute) {
          _wakeLog.warn(
            'Skipping wake navigation reset while zkPassport flow is active',
          );
          return;
        }
        final navContext = appNavigatorKey.currentContext;
        if (navContext == null) return;
        _wakeLog.warn('Navigating to home after app wake');
        GoRouter.of(navContext).go(AppRoutes.home);
      });
    }
    _wasSleeping = isSleeping;
  }

  void _handleSleepScreenWakeRequested() {
    unawaited(
      _appSleepService.wake(reason: AppSleepService.manualUiWakeReason),
    );
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

    if (MetricsReportingService.instance.isRunning) {
      await MetricsReportingService.instance.reportNow();
    }
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
      child: ListenableBuilder(
        listenable: _appSleepService,
        builder: (context, child) {
          final snapshot = _appSleepService.snapshot;
          final showSleepScreen = snapshot.isSleeping &&
              snapshot.lifecycleState == AppLifecycleState.resumed;
          return TickerMode(
            enabled: !_appSleepService.isSleeping,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const ClockDriftWarningOverlay(),
                if (showSleepScreen)
                  AppSleepScreen(
                    snapshot: snapshot,
                    onWakeRequested: _handleSleepScreenWakeRequested,
                  ),
              ],
            ),
          );
        },
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}
