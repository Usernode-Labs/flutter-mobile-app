import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

/// Parse a log level string to [Level]
Level _parseLevel(String levelStr) {
  switch (levelStr.toLowerCase()) {
    case 'trace':
      return Level.trace;
    case 'debug':
      return Level.debug;
    case 'info':
      return Level.info;
    case 'warning':
    case 'warn':
      return Level.warning;
    case 'error':
      return Level.error;
    default:
      return Level.info;
  }
}

/// Simple logging service with file output support.
///
/// Usage:
/// ```dart
/// final _log = LoggingService.instance.withTag('usernode/MyClass');
/// _log.info('Something happened');
/// ```
class LoggingService {
  LoggingService._(this._logger);

  static LoggingService? _instance;
  static LoggingService get instance => _instance ?? _createDefault();

  final Logger _logger;

  // Global log level from config
  static final Level _globalLevel = _parseLevel(AppConfig.logLevel);

  /// Initialize logging with file output (debug mode only).
  /// Call this early in main() before any logging.
  static Future<void> initialize() async {
    if (_instance != null) return;

    final fileOutput = FileLogOutput();
    await fileOutput.init();

    _instance = LoggingService._(Logger(
      filter: _AppLogFilter(),
      printer: _CustomLogPrinter(),
      output: MultiOutput([ConsoleOutput(), fileOutput]),
    ));
  }

  /// Create default instance (console only, for early logging before init)
  static LoggingService _createDefault() {
    _instance = LoggingService._(Logger(
      filter: _AppLogFilter(),
      printer: _CustomLogPrinter(),
    ));
    return _instance!;
  }

  void trace(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(Level.trace, message, tag: tag, context: context);
  }

  void debug(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(Level.debug, message, tag: tag, context: context);
  }

  void info(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(Level.info, message, tag: tag, context: context);
  }

  void warn(String message, {String? tag, Map<String, dynamic>? context}) {
    _log(Level.warning, message, tag: tag, context: context);
  }

  void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final formatted = _decorate(message, tag, context);
    _logger.e(formatted, error: error, stackTrace: stackTrace);

    // Send to Sentry - always capture errors, not just breadcrumbs
    if (error != null && stackTrace != null) {
      // ignore: discarded_futures
      SentryUtil.captureError(error, stackTrace, tag: tag, context: context);
    } else {
      // Capture as error message even without exception/stackTrace
      final errorMessage = tag != null ? '[$tag] $message' : message;
      // ignore: discarded_futures
      SentryUtil.captureMessage(errorMessage, level: SentryLevel.error);
    }
  }

  /// Create a tagged logger for cleaner per-file usage
  TaggedLogger withTag(String tag) => TaggedLogger._(tag, this);

  void _log(
    Level level,
    String message, {
    String? tag,
    Map<String, dynamic>? context,
  }) {
    // Console/file logging
    if (level.index >= _globalLevel.index) {
      final formatted = _decorate(message, tag, context);

      switch (level) {
        case Level.trace:
          _logger.t(formatted);
        case Level.debug:
          _logger.d(formatted);
        case Level.info:
          _logger.i(formatted);
        case Level.warning:
          _logger.w(formatted);
        default:
          break;
      }
    }

    // Only add breadcrumbs for warning+ logs to reduce noise
    if (level.index >= Level.warning.index) {
      SentryUtil.addBreadcrumb(
        category: tag ?? 'logging',
        message: message,
        data: context,
        level: _levelToSentryLevel(level),
      );
    }
  }

  String _decorate(String message, String? tag, Map<String, dynamic>? context) {
    var result = message.trim().isEmpty ? '<empty>' : message.trim();

    if (tag != null && tag.isNotEmpty) {
      result = '[$tag] $result';
    }

    if (context != null && context.isNotEmpty) {
      final contextStr =
          context.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      result = '$result {$contextStr}';
    }

    return result;
  }

  SentryLevel _levelToSentryLevel(Level level) {
    switch (level) {
      case Level.trace:
      case Level.debug:
        return SentryLevel.debug;
      case Level.info:
        return SentryLevel.info;
      case Level.warning:
        return SentryLevel.warning;
      case Level.error:
        return SentryLevel.error;
      case Level.fatal:
        return SentryLevel.fatal;
      default:
        return SentryLevel.info;
    }
  }
}

/// Logger wrapper with a pre-bound tag.
///
/// Usage:
/// ```dart
/// final _log = LoggingService.instance.withTag('usernode/NodeService');
/// _log.info('message');
/// ```
class TaggedLogger {
  final String _tag;
  final LoggingService _service;

  TaggedLogger._(this._tag, this._service);

  void trace(String message, {Map<String, dynamic>? context}) =>
      _service.trace(message, tag: _tag, context: context);

  void debug(String message, {Map<String, dynamic>? context}) =>
      _service.debug(message, tag: _tag, context: context);

  void info(String message, {Map<String, dynamic>? context}) =>
      _service.info(message, tag: _tag, context: context);

  void warn(String message, {Map<String, dynamic>? context}) =>
      _service.warn(message, tag: _tag, context: context);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) =>
      _service.error(
        message,
        tag: _tag,
        error: error,
        stackTrace: stackTrace,
        context: context,
      );
}

/// Log filter - disable all logging in release mode
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // if (kReleaseMode) return false;
    return true;
  }
}

/// Custom log printer with timestamps
class _CustomLogPrinter extends LogPrinter {
  static final _labels = {
    Level.trace: '[TRACE]',
    Level.debug: '[DEBUG]',
    Level.info: '[INFO]',
    Level.warning: '[WARN]',
    Level.error: '[ERROR]',
    Level.fatal: '[FATAL]',
  };

  @override
  List<String> log(LogEvent event) {
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';

    final label = _labels[event.level] ?? '';
    final lines = <String>['$timeStr $label ${event.message}'];

    if (event.error != null) {
      lines.add('  Error: ${event.error}');
    }

    if (event.stackTrace != null && event.level.index >= Level.error.index) {
      final frames = event.stackTrace.toString().split('\n').take(10);
      for (final frame in frames) {
        if (frame.trim().isNotEmpty) lines.add('  $frame');
      }
    }

    return lines;
  }
}

/// File output - writes logs to app support directory
class FileLogOutput extends LogOutput {
  IOSink? _sink;

  @override
  Future<void> init() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final logDir = Directory('${dir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final file = File('${logDir.path}/app.log');
      _sink = file.openWrite(mode: FileMode.append);
      if (kDebugMode) print('Log file: ${file.path}');
    } catch (e) {
      if (kDebugMode) print('Failed to init file logging: $e');
    }
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null) return;
    for (final line in event.lines) {
      _sink!.writeln(line);
    }
  }

  @override
  Future<void> destroy() async {
    await _sink?.flush();
    await _sink?.close();
  }
}

/// Multi-output - writes to multiple outputs
class MultiOutput extends LogOutput {
  final List<LogOutput> outputs;

  MultiOutput(this.outputs);

  @override
  void output(OutputEvent event) {
    for (final o in outputs) {
      o.output(event);
    }
  }

  @override
  Future<void> destroy() async {
    for (final o in outputs) {
      await o.destroy();
    }
  }
}
