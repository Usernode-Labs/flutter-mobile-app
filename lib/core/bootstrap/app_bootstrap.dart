import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
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
    // Both feed ThemeModeController's synchronous seed, so they have to be
    // resolved BEFORE the first frame: a theme read that lands afterwards
    // repaints the splash instead of painting it right the first time.
    await ThemeModeStorage.init();
    await AppearanceStorage.init();
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
      await RustLib.init(
        // The Apple pod links Rust statically into the application binary, so
        // its symbols must be resolved from the process rather than dlopen.
        externalLibrary: Platform.isIOS || Platform.isMacOS
            ? ExternalLibrary.process(iKnowHowToUseIt: true)
            : null,
      );
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
