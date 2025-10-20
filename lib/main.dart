import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/theme/theme.dart';
import 'gen_l10n/app_localizations.dart';
import 'package:crypto_mobile_app/features/node/data/repositories/rust_backend_service.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/routing/app_router.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SentryUtil.bootstrap(() async {
    SentryUtil.addBreadcrumb(category: 'app', message: 'startup begin');

    // Render UI immediately; perform heavy bootstrap asynchronously.
    Log.i('MAIN', 'Running app UI');
    SentryUtil.addBreadcrumb(category: 'app', message: 'runApp');
    runApp(const ProviderScope(child: CryptoMobileApp()));
    // Track lifecycle changes for breadcrumbs/diagnostics
    AppLifecycleLogger.register();

    // Kick off non-blocking bootstrap work (feature flags, backend, etc).
    // ignore: unawaited_futures
    _bootstrapAsync();
  });
}

Future<void> _bootstrapAsync() async {
  try {
    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap begin');
    Log.i('MAIN', 'Initializing application');

    // Log environment/config for diagnostics
    final cfg = AppConfig.instance;
    SentryUtil.addBreadcrumb(category: 'config', message: 'env', data: {
      'environment': cfg.environment,
      'apiBaseUrl': cfg.apiBaseUrl,
      'verboseLogging': cfg.verboseLogging,
    });

    // Load feature flags from assets (if provided)
    await FeatureFlags.loadFromAssetIfAvailable();
    if (kDebugMode) {
      Log.d(
        'MAIN',
        'Feature flags loaded: ${FeatureFlags.ordered.where(FeatureFlags.isEnabled).toList()}',
      );
    }

    // Initialize FRB only; start backend only if an account exists
    await RustBackendService.instance.init();
    final started = await RustBackendService.instance.startForActiveAccount();
    Log.i('MAIN', 'Backend startForActiveAccount => $started');
    await SentryUtil.captureMessage(
      started
          ? 'backend startForActiveAccount: started'
          : 'backend startForActiveAccount: skipped',
    );

    SentryUtil.addBreadcrumb(category: 'app', message: 'bootstrap end');
  } catch (e, st) {
    Log.e('MAIN', 'Bootstrap failed: $e');
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
