import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentrySettings {
  final String dsn;
  final String environment;
  final double tracesSampleRate;
  final double profilesSampleRate;

  const SentrySettings({
    required this.dsn,
    required this.environment,
    required this.tracesSampleRate,
    required this.profilesSampleRate,
  });

  // DSN is read from --dart-define SENTRY_DSN. No hard-coded default.
  static const String _dsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static const String _env =
      String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'development');
  static const String _traces =
      String.fromEnvironment('SENTRY_TRACES_SAMPLE_RATE', defaultValue: '0.2');
  static const String _profiles = String.fromEnvironment(
      'SENTRY_PROFILES_SAMPLE_RATE',
      defaultValue: '0.0');

  static double _parseRate(String s, double fallback) {
    final v = double.tryParse(s);
    if (v == null || v.isNaN || v < 0 || v > 1) return fallback;
    return v;
  }

  factory SentrySettings.fromEnvironment() {
    return SentrySettings(
      dsn: _dsn,
      environment: _env,
      tracesSampleRate: _parseRate(_traces, 0.2),
      profilesSampleRate: _parseRate(_profiles, 0.0),
    );
  }
}

class SentryUtil {
  static bool _enabled = false;
  // Gate for logging large payloads (enable in dev/staging)
  static const bool logStatusPayload =
      bool.fromEnvironment('SENTRY_LOG_STATUS_PAYLOAD', defaultValue: true);
  static Future<void> bootstrap(
    FutureOr<void> Function() appRunner, {
    SentrySettings? settings,
  }) async {
    final opts = settings ?? SentrySettings.fromEnvironment();
    if (opts.dsn.isEmpty) {
      // Run app without initializing Sentry if DSN is not provided.
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
      options.enableAutoPerformanceTracing = true;
      options.sendDefaultPii = false;
      options.enableAppLifecycleBreadcrumbs = true;
    }, appRunner: () async {
      _enabled = true;
      await Future.sync(appRunner);
    });
  }

  static List<NavigatorObserver> navigatorObservers() {
    if (!_enabled) return const <NavigatorObserver>[];
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
    // Breadcrumbs are best-effort even if Sentry is disabled.
    Sentry.addBreadcrumb(Breadcrumb(
      category: category,
      message: message,
      data: data,
      level: level,
    ));
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
