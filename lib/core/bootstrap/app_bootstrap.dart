import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';
import 'package:crypto_mobile_app/core/services/android_foreground_task_controller.dart';
import 'package:crypto_mobile_app/core/services/platform_alarm_service.dart';
import 'package:crypto_mobile_app/core/services/deep_link_service.dart';
import 'package:crypto_mobile_app/core/utils/lifecycle.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/features/metrics/metrics_collector_service.dart';
import 'package:crypto_mobile_app/features/node/node_service.dart';
import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/features/zkpassport/providers/zkpassport_flow_provider.dart';

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
      AndroidForegroundTaskController.instance.handleNativeEvent,
    );

    // Create provider container
    final container = ProviderContainer();

    // Accounts are needed to decide background behavior and set crash context
    final repo = await AccountsRepository.create();
    final hasAnyAccounts = await repo.hasAny();
    final activeId = repo.getActiveId();

    if (activeId != null && SentryUtil.enabled) {
      await SentryUtil.setUser(id: activeId);
      log.debug('Set Sentry user context for existing account: $activeId');
    }

    // Metrics collector needs the container before any lifecycle/service starts
    MetricsCollectorService.instance.initialize(container);

    if (registerLifecycleObserver) {
      AppLifecycleLogger.register();
      AppLifecycleLogger.onForegroundResume = () {
        container
            .read(zkPassportPipelineProvider.notifier)
            .recoverPendingSessionOnForeground();
      };
    }

    DeepLinkService.instance.initialize(
      onZkCallback: () {
        container
            .read(zkPassportPipelineProvider.notifier)
            .recoverPendingSessionOnForeground();
      },
    );

    _bootstrapBackendAsync(log: log, container: container);

    return AppBootstrapResult(
      container: container,
      log: log,
      hasAnyAccounts: hasAnyAccounts,
      activeAccountId: activeId,
    );
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
