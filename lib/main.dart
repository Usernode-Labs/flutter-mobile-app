import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/theme/theme.dart';
import 'core/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/routing/app_router.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';
import 'package:crypto_mobile_app/features/metrics/domain/services/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/metrics/presentation/controllers/metrics_lifecycle_provider.dart';
import 'package:crypto_mobile_app/core/config/blockchain_timing.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/background_block_production_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/routing/new_ux_router.dart';

const bool kNewUx =
    bool.fromEnvironment('NEW_UX', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final log = LoggingService();
  await SentryUtil.bootstrap(() async {
    SentryUtil.addBreadcrumb(category: 'app', message: 'startup begin');
    log.info('App started', tag: 'MAIN');

    // Create provider container and initialize blockchain timing
    final container = ProviderContainer();
    BlockchainTiming.initialize(container);

    // Render UI immediately; perform heavy bootstrap asynchronously.
    log.info('Running app UI', tag: 'MAIN');
    SentryUtil.addBreadcrumb(category: 'app', message: 'runApp');
    runApp(UncontrolledProviderScope(
        container: container, child: const CryptoMobileApp()));
    // Track lifecycle changes for breadcrumbs/diagnostics
    AppLifecycleLogger.register();

    // Kick off non-blocking bootstrap work (feature flags, backend, etc).
    // ignore: unawaited_futures
    _bootstrapAsync(log, container);
  });
}

Future<void> _bootstrapAsync(
    LoggingService log, ProviderContainer container) async {
  try {
    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap begin');
    log.info('Initializing application', tag: 'MAIN');

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
        'Feature flags loaded: ${FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList()}',
        tag: 'MAIN',
      );
    }

    // Initialize FRB only; start backend only if an account exists
    if (!RustBackendService.instance.isRunning) {
      await RustBackendService.instance.init();
      final started = await RustBackendService.instance.startNode();
      log.info('Backend startNode => $started', tag: 'MAIN');
      await SentryUtil.captureMessage(
        started
            ? 'backend startNode: started'
            : 'backend startNode: skipped',
      );
    }

    // Initialize metrics collection service
    log.info('Initializing metrics collection service', tag: 'MAIN');
    MetricsCollectorService.instance.initialize(container);

    // Initialize background block production orchestrator
    log.info('Initializing background block production orchestrator',
        tag: 'MAIN');
    await BackgroundBlockProductionOrchestrator.instance.initialize();

    // Request permissions at startup (if not already requested)
    // Skip for NEW_UX; permissions are requested in the onboarding flow (screen 3)
    if (!kNewUx) {
      await _requestPermissionsAtStartup(log);
    }

    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap end');
  } catch (e, st) {
    log.error('Bootstrap failed: $e', tag: 'MAIN', error: e, stackTrace: st);
    await SentryUtil.captureError(e, st, tag: 'bootstrap');
  }
}

/// Request necessary permissions at app startup
Future<void> _requestPermissionsAtStartup(LoggingService log) async {
  try {
    // Check if we've already requested permissions to avoid annoying users
    final prefs = await SharedPreferences.getInstance();
    final hasRequestedPermissions =
        prefs.getBool('has_requested_permissions_at_startup') ?? false;

    if (hasRequestedPermissions) {
      log.info('Permissions already requested at startup previously',
          tag: 'PERMISSIONS');
      return;
    }

    log.info('Requesting permissions at startup...', tag: 'PERMISSIONS');
    SentryUtil.addBreadcrumb(
        category: 'permissions', message: 'startup request begin');

    // Initialize platform alarm service
    await PlatformAlarmService.instance.initialize();

    // Request all necessary permissions
    final granted = await PlatformAlarmService.instance.requestPermissions();

    if (granted) {
      log.info('All required permissions granted', tag: 'PERMISSIONS');
    } else {
      log.warn('Some permissions were not granted', tag: 'PERMISSIONS');
    }

    // Mark that we've requested permissions
    await prefs.setBool('has_requested_permissions_at_startup', true);

    SentryUtil.addBreadcrumb(
      category: 'permissions',
      message: 'startup request complete',
      data: {'granted': granted},
    );
  } catch (e, st) {
    log.error('Error requesting permissions at startup: $e',
        tag: 'PERMISSIONS', error: e, stackTrace: st);
    await SentryUtil.captureError(e, st, tag: 'permissions_startup');
  }
}

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = kNewUx
        ? ref.watch(newUxRouterProvider)
        : ref.watch(appRouterProvider);
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
