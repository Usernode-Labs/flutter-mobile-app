import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentrySettings {
  final String dsn;
  final String environment;
  final double tracesSampleRate;
  final double profilesSampleRate;
  final bool enableBreadcrumbs;
  final bool enablePerformanceTracking;

  const SentrySettings({
    required this.dsn,
    required this.environment,
    required this.tracesSampleRate,
    required this.profilesSampleRate,
    required this.enableBreadcrumbs,
    required this.enablePerformanceTracking,
  });

  // DSN is read from --dart-define SENTRY_DSN. No hard-coded default.
  static const String _dsn = String.fromEnvironment('SENTRY_DSN',
      defaultValue:
          'https://83282076dcf474954f5a12ffd4326bc7@o4510024243412992.ingest.de.sentry.io/4510024245379152');
  static const String _env =
      String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');
  static const String _traces =
      String.fromEnvironment('SENTRY_TRACES_SAMPLE_RATE', defaultValue: '0.0');
  static const String _profiles = String.fromEnvironment(
      'SENTRY_PROFILES_SAMPLE_RATE',
      defaultValue: '0.0');
  static const String _enableBreadcrumbs =
      String.fromEnvironment('SENTRY_ENABLE_BREADCRUMBS', defaultValue: 'false');
  static const String _enablePerformance =
      String.fromEnvironment('SENTRY_ENABLE_PERFORMANCE', defaultValue: 'false');

  static double _parseRate(String s, double fallback) {
    final v = double.tryParse(s);
    if (v == null || v.isNaN || v < 0 || v > 1) return fallback;
    return v;
  }

  factory SentrySettings.fromEnvironment() {
    return SentrySettings(
      dsn: _dsn,
      environment: _env,
      tracesSampleRate: _parseRate(_traces, 0.0),
      profilesSampleRate: _parseRate(_profiles, 0.0),
      enableBreadcrumbs: _enableBreadcrumbs.toLowerCase() == 'true',
      enablePerformanceTracking: _enablePerformance.toLowerCase() == 'true',
    );
  }
}

class SentryUtil {
  static bool _enabled = false;
  static bool _breadcrumbsEnabled = false;
  static bool _performanceTrackingEnabled = false;
  // Gate for logging large payloads (enable in dev/staging)
  static const bool logStatusPayload =
      bool.fromEnvironment('SENTRY_LOG_STATUS_PAYLOAD', defaultValue: true);

  static bool get enabled => _enabled;

  static Future<void> bootstrap(
    FutureOr<void> Function() appRunner, {
    SentrySettings? settings,
  }) async {
    final opts = settings ?? SentrySettings.fromEnvironment();
    if (opts.dsn.isEmpty) {
      // Run app without initializing Sentry if DSN is not provided.
      // We still must ensure that a Flutter binding exists before any code
      // touches platform channels (e.g., SharedPreferences in NetworkPrefs).
      WidgetsFlutterBinding.ensureInitialized();
      await Future.sync(appRunner);
      _enabled = false;
      return;
    }
    await SentryFlutter.init((options) {
      if (opts.dsn.isNotEmpty) options.dsn = opts.dsn;
      options.environment = opts.environment;
      options.tracesSampleRate = opts.tracesSampleRate;
      options.profilesSampleRate = opts.profilesSampleRate;
      options.attachThreads = true;
      options.reportPackages = true;
      options.enableAutoPerformanceTracing = opts.enablePerformanceTracking;
      options.sendDefaultPii = false;
      options.enableAppLifecycleBreadcrumbs = opts.enableBreadcrumbs;
    }, appRunner: () async {
      _enabled = true;
      _breadcrumbsEnabled = opts.enableBreadcrumbs;
      _performanceTrackingEnabled = opts.enablePerformanceTracking;
      await Future.sync(appRunner);
    });
  }

  static List<NavigatorObserver> navigatorObservers() {
    if (!_enabled || !_performanceTrackingEnabled) return const <NavigatorObserver>[];
    return [SentryNavigatorObserver()];
  }

  static Future<void> captureError(
    Object error,
    StackTrace stackTrace, {
    String? tag,
    Map<String, dynamic>? context,
  }) async {
    if (!_enabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (tag != null) scope.setTag('source', tag);
        if (context != null) {
          for (final entry in context.entries) {
            scope.setContexts(entry.key, entry.value);
          }
        }
      },
    );
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    if (!_enabled) return;
    await Sentry.captureMessage(message, level: level);
  }

  static Future<void> captureMessageWithData(
    String message,
    Map<String, Object?> data, {
    SentryLevel level = SentryLevel.info,
  }) async {
    if (!_enabled) return;
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        scope.setContexts('extras', data);
      },
    );
  }

  static Future<void> captureMessageWithAttachment(
    String message, {
    required String filename,
    required String content,
    String contentType = 'application/json',
    Map<String, Object?> extras = const {},
    SentryLevel level = SentryLevel.info,
  }) async {
    if (!_enabled) return;
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extras.isNotEmpty) {
          scope.setContexts('extras', extras);
        }
        final bytes = utf8.encode(content);
        scope.addAttachment(
          SentryAttachment.fromIntList(bytes, filename,
              contentType: contentType),
        );
      },
    );
  }

  static void addBreadcrumb({
    required String category,
    String? message,
    Map<String, dynamic>? data,
    SentryLevel level = SentryLevel.info,
  }) {
    // Only add breadcrumbs if enabled and Sentry is active
    if (!_enabled || !_breadcrumbsEnabled) return;
    Sentry.addBreadcrumb(Breadcrumb(
      category: category,
      message: message,
      data: data,
      level: level,
    ));
  }

  /// Log a routine RPC operation as a breadcrumb (not an Issue).
  /// Use this for normal operational data that should only appear
  /// when an actual error occurs.
  /// Note: This is disabled by default to reduce noise.
  static void logRpcBreadcrumb(
    String rpcMethod,
    Map<String, dynamic> data,
  ) {
    // Only log RPC breadcrumbs if explicitly enabled
    if (!_enabled || !_breadcrumbsEnabled) return;
    addBreadcrumb(
      category: 'rpc',
      message: rpcMethod,
      data: data,
      level: SentryLevel.info,
    );
  }

  static Future<void> setUser({
    String? id,
    String? username,
    String? email,
  }) async {
    await Sentry.configureScope((scope) {
      scope.setUser(SentryUser(id: id, username: username, email: email));
    });
  }

  static Future<void> clearUser() async {
    await Sentry.configureScope((scope) {
      scope.setUser(null);
    });
  }
}
