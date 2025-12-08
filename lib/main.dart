import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/config/theme.dart';
import 'core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_provider.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:crypto_mobile_app/features/wallet/accounts_provider.dart';
import 'package:crypto_mobile_app/features/node/produced_blocks_provider.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/services/app_version_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize network preferences early (before any SharedPreferences access)
  await NetworkPrefs.init();

  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final log = LoggingService.instance.withTag(LogTag.bootstrap);

  await SentryUtil.bootstrap(() async {
    SentryUtil.addBreadcrumb(category: 'app', message: 'startup begin');
    log.info('App started');

    // Create provider container
    final container = ProviderContainer();

    final repo = await AccountsRepository.create();
    final hasAnyAccounts = await repo.hasAny();
    log.info('hasAnyAccounts: $hasAnyAccounts');

    // Render UI immediately; perform heavy bootstrap asynchronously.
    log.info('Running app UI');

    SentryUtil.addBreadcrumb(category: 'app', message: 'runApp');
    runApp(UncontrolledProviderScope(
        container: container,
        child: CryptoMobileApp(hasAccount: hasAnyAccounts)));
    // Track lifecycle changes for breadcrumbs/diagnostics
    AppLifecycleLogger.register();

    // Kick off non-blocking bootstrap work (feature flags, backend, etc).
    // ignore: unawaited_futures
    _bootstrapAsync(log, container);
  });
}

Future<void> _bootstrapAsync(
    TaggedLogger log, ProviderContainer container) async {
  try {
    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap begin');
    log.info('Initializing application');

    // Log environment/config for diagnostics
    final cfg = AppConfig.instance;
    SentryUtil.addBreadcrumb(category: 'config', message: 'env', data: {
      'environment': cfg.environment,
      'verboseLogging': cfg.verboseLogging,
    });

    // Load feature flags from assets (if provided)
    await FeatureFlags.loadFromAssetIfAvailable();
    if (kDebugMode) {
      log.debug(
          'Feature flags loaded: ${FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList()}');
    }

    // Initialize FRB only; start backend only if an account exists
    if (!RustBackendService.instance.isRunning) {
      await RustBackendService.instance.init();
      final started = await RustBackendService.instance.startNode();
      log.info('Backend startNode => $started');
      await SentryUtil.captureMessage(
        started ? 'backend startNode: started' : 'backend startNode: skipped',
      );
    }

    // Initialize metrics collection service
    log.info('Initializing metrics collection service');
    MetricsCollectorService.instance.initialize(container);

    // Initialize background block production orchestrator
    log.info('Initializing background block production orchestrator');
    await BackgroundBlockProductionOrchestrator.instance.initialize();

    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap end');
  } catch (e, st) {
    log.error('Bootstrap failed: $e');
    await SentryUtil.captureError(e, st, tag: 'bootstrap');
  }
}

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key, required this.hasAccount});
  final bool hasAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize backend lifecycle manager
    ref.watch(backendLifecycleProvider);

    // Initialize metrics lifecycle manager
    ref.watch(metricsLifecycleProvider);

    return MaterialApp.router(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appName,
      theme: MaterialTheme(ThemeData.light().textTheme).light(),
      darkTheme: MaterialTheme(ThemeData.dark().textTheme).dark(),
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
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
    final log = LoggingService.instance.withTag(LogTag.versionCheck);
    log.info('_checkInitialVersion called');
    try {
      final result = await ref.read(appVersionCheckProvider.future);
      log.info('Version check result: $result, shouldShow: ${result?.shouldShowDialog}, shown: $_versionCheckShown, mounted: $mounted');
      if (result != null && result.shouldShowDialog && !_versionCheckShown && mounted) {
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

