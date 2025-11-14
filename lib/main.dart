import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:crypto_mobile_app/core/services/local_notification_service.dart';
import 'package:crypto_mobile_app/core/services/background_task_service.dart';
import 'package:crypto_mobile_app/core/data/notification_state_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final log = LoggingService();
  await SentryUtil.bootstrap(() async {
    SentryUtil.addBreadcrumb(category: 'app', message: 'startup begin');
    log.info('App started', tag: 'MAIN');

    // Render UI immediately; perform heavy bootstrap asynchronously.
    log.info('Running app UI', tag: 'MAIN');
    SentryUtil.addBreadcrumb(category: 'app', message: 'runApp');
    runApp(const ProviderScope(child: CryptoMobileApp()));
    // Track lifecycle changes for breadcrumbs/diagnostics
    AppLifecycleLogger.register();

    // Kick off non-blocking bootstrap work (feature flags, backend, etc).
    // ignore: unawaited_futures
    _bootstrapAsync(log);
  });
}

Future<void> _bootstrapAsync(LoggingService log) async {
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

    // Initialize notification services
    log.info('Initializing notification services', tag: 'MAIN');
    await NotificationStateRepository.instance.initialize();
    final notificationInitialized =
        await LocalNotificationService.instance.initialize();
    log.info('Notification service initialized: $notificationInitialized',
        tag: 'MAIN');

    if (notificationInitialized) {
      // Request permissions
      final permissionsGranted =
          await LocalNotificationService.instance.requestPermissions();
      log.info('Notification permissions granted: $permissionsGranted',
          tag: 'MAIN');

      // Initialize background tasks
      final backgroundInitialized =
          await BackgroundTaskService.instance.initialize();
      log.info('Background task service initialized: $backgroundInitialized',
          tag: 'MAIN');

      if (backgroundInitialized &&
          NotificationStateRepository.instance.notificationsEnabled) {
        // Register periodic background task for slot monitoring
        await BackgroundTaskService.instance.registerSlotMonitoringTask();
        log.info('Slot monitoring background task registered', tag: 'MAIN');
      }
    }

    // Initialize FRB only; start backend only if an account exists
    await RustBackendService.instance.init();
    final started = await RustBackendService.instance.startForActiveAccount();
    log.info('Backend startForActiveAccount => $started', tag: 'MAIN');
    await SentryUtil.captureMessage(
      started
          ? 'backend startForActiveAccount: started'
          : 'backend startForActiveAccount: skipped',
    );

    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap end');
  } catch (e, st) {
    log.error('Bootstrap failed: $e', tag: 'MAIN', error: e, stackTrace: st);
    await SentryUtil.captureError(e, st, tag: 'bootstrap');
  }
}

class CryptoMobileApp extends ConsumerWidget {
  const CryptoMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Initialize backend lifecycle manager
    ref.watch(backendLifecycleProvider);

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
