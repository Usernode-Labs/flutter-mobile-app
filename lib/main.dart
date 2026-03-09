import 'dart:async';
import 'dart:convert';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_reporting_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'package:crypto_mobile_app/core/providers/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';
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

    // Render UI immediately; perform heavy bootstrap asynchronously.
    log.info('Running app UI');
    runApp(UncontrolledProviderScope(
        container: boot.container,
        child: CryptoMobileApp(hasAccount: boot.hasAnyAccounts)));
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
    final boot = await AppBootstrap.initNonUi(
      logTag: 'usernode/HeadlessBootstrap',
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
      log.error('Error during headless bootstrap: $e',
          error: e, stackTrace: st);
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
    ProviderContainer container, TaggedLogger log) async {
  try {
    log.info('Starting headless services (metrics, lifecycle, etc.)');

    _startHeadlessProducedBlocksRefresh(container, log);

    // Start metrics reporting service if enabled
    if (AppConfig.metricsEnabled && AppConfig.metricsEndpoint.isNotEmpty) {
      log.info('Starting metrics reporting service in headless mode', context: {
        'endpoint': AppConfig.metricsEndpoint,
        'interval_seconds': AppConfig.metricsCollectionIntervalSeconds,
      });
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
                'Account address not in UTXO format, skipping balance calculation');
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

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key, required this.hasAccount});
  final bool hasAccount;

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

class _AppWrapperState extends ConsumerState<_AppWrapper> {
  bool _versionCheckShown = false;

  @override
  void initState() {
    super.initState();
    // Start periodic version checks
    AppVersionCheck.instance.startPeriodicChecks(_handleVersionCheckResult);
    // Check version after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialVersion());
  }

  Future<void> _checkInitialVersion() async {
    final log = LoggingService.instance.withTag('usernode/VersionCheck');
    log.info('_checkInitialVersion called');
    try {
      final result = await ref.read(appVersionCheckProvider.future);
      log.info(
          'Version check result: $result, shouldShow: ${result?.shouldShowDialog}, shown: $_versionCheckShown, mounted: $mounted');
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
    AppVersionCheck.instance.stopPeriodicChecks();
    super.dispose();
  }

  void _handleVersionCheckResult(VersionCheckResult result) {
    if (!mounted) return;
    showUpdateDialog(appNavigatorKey, result);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Invalidate only the produced blocks summary provider on hot reload.
    ref.invalidate(producedBlocksSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
