import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/services/app_sleep_state_store.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';

final class AppBootstrapResult {
  const AppBootstrapResult({
    required this.container,
    required this.log,
    required this.rustBootstrap,
  });

  final ProviderContainer container;
  final TaggedLogger log;
  final Future<void> rustBootstrap;
}

/// Process bootstrap that deliberately does not restore an application
/// identity, start a node, or own OS scheduling.
///
/// The private native session composition root performs the sole lifecycle
/// bootstrap after [rustBootstrap] completes. Android/iOS background entry is
/// native-to-Rust and therefore never constructs this Flutter graph.
abstract final class AppBootstrap {
  static Future<AppBootstrapResult> initNonUi({
    required String logTag,
    bool installErrorHandlers = true,
  }) async {
    await LoggingService.initialize();
    await DebugModeStorage.init();
    await AppSleepStateStore.load();

    final log = LoggingService.instance.withTag(logTag);
    if (installErrorHandlers) _installGlobalErrorHandlers(log);

    final config = AppConfig.instance;
    log.debug('Environment config loaded', context: {
      'environment': config.environment,
      'verboseLogging': config.verboseLogging,
    });

    return AppBootstrapResult(
      container: ProviderContainer(),
      log: log,
      rustBootstrap: _initializeRust(log),
    );
  }

  static Future<void> _initializeRust(TaggedLogger log) async {
    try {
      await RustLib.init();
      log.info('Restricted native API initialized');
    } catch (error, stackTrace) {
      log.error(
        'Restricted native API initialization failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static void _installGlobalErrorHandlers(TaggedLogger log) {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      log.error(
        'Flutter framework error',
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        context: {'library': details.library ?? 'unknown'},
      );
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      log.error(
        'Uncaught async error',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    };
  }
}
