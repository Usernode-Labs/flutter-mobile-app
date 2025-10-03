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

  //TODO: switch to secret manager or CI/CD variables. remove hard coded DSN from here
  static const String _dsn = String.fromEnvironment('SENTRY_DSN',
      defaultValue:
          'https://1132c9cc57d02380c5ac2927deba492e@o4510024243412992.ingest.de.sentry.io/4510024245379152');
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
  // Gate for logging large payloads (enable in dev/staging)
  static const bool logStatusPayload =
      bool.fromEnvironment('SENTRY_LOG_STATUS_PAYLOAD', defaultValue: true);
  static Future<void> bootstrap(
    FutureOr<void> Function() appRunner, {
    SentrySettings? settings,
  }) async {
    final opts = settings ?? SentrySettings.fromEnvironment();
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
    }, appRunner: appRunner);
  }

  static List<NavigatorObserver> navigatorObservers() {
    return [SentryNavigatorObserver()];
  }

  static Future<void> captureError(
    Object error,
    StackTrace stackTrace, {
    String? tag,
  }) async {
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (tag != null) scope.setTag('source', tag);
      },
    );
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    await Sentry.captureMessage(message, level: level);
  }

  static Future<void> captureMessageWithData(
    String message,
    Map<String, Object?> data, {
    SentryLevel level = SentryLevel.info,
  }) async {
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
    await Sentry.captureMessage(
      message,
      level: level,
      withScope: (scope) {
        if (extras.isNotEmpty) {
          scope.setContexts('extras', extras);
        }
        final bytes = utf8.encode(content);
        scope.addAttachment(
          SentryAttachment.fromIntList(bytes, filename, contentType: contentType),
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
