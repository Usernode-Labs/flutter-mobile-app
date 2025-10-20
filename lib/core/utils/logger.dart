import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';

/// Application-wide logging facade backed by the `logger` package.
///
/// - Prints to console in debug/profile builds.
/// - In release builds, only `error` logs emit console output.
/// - Errors automatically forward to Sentry when an [error] and [stackTrace]
///   are supplied; otherwise a breadcrumb is recorded.
class LoggingService {
  factory LoggingService({Logger? logger}) {
    if (logger != null) {
      return LoggingService._(logger);
    }
    return _shared;
  }

  LoggingService._(Logger logger) : _logger = logger;

  static final LoggingService _shared = LoggingService._(
    Logger(
      filter: _AppLogFilter(),
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
        noBoxingByDefault: true,
      ),
    ),
  );

  static LoggingService get instance => _shared;

  final Logger _logger;

  void trace(String message, {String? tag}) {
    _logger.t(_decorate(message, tag));
  }

  void debug(String message, {String? tag}) {
    _logger.d(_decorate(message, tag));
  }

  void info(String message, {String? tag}) {
    _logger.i(_decorate(message, tag));
  }

  void warn(String message, {String? tag}) {
    _logger.w(_decorate(message, tag));
  }

  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final formatted = _decorate(message, tag);
    _logger.e(formatted, error: error, stackTrace: stackTrace);

    if (error != null && stackTrace != null) {
      // Fire-and-forget; ignore failures.
      // ignore: discarded_futures
      SentryUtil.captureError(error, stackTrace, tag: tag ?? 'logging');
    } else {
      SentryUtil.addBreadcrumb(
        category: tag ?? 'logging',
        message: message,
      );
    }
  }

  String _decorate(String message, String? tag) {
    if (tag == null || tag.isEmpty) return message;
    return '[$tag] $message';
  }
}

class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode || kProfileMode) {
      return true;
    }
    // In release builds, suppress lower-severity logs.
    return event.level.index >= Level.error.index;
  }
}
