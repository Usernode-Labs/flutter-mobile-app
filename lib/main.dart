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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    );
  }
}
