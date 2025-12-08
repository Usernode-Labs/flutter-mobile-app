import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
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

/// Parse tag-level overrides from config string (format: tag:level,tag:level)
Map<LogTag, Level> _parseTagLevels(String config) {
  if (config.isEmpty) return {};
  final result = <LogTag, Level>{};
  for (final entry in config.split(',')) {
    final parts = entry.trim().split(':');
    if (parts.length == 2) {
      final tagName = parts[0].trim().toLowerCase();
      final level = _parseLevel(parts[1].trim());
      // Find matching LogTag by value or name (case-insensitive)
      for (final tag in LogTag.values) {
        if (tag.value.toLowerCase() == tagName ||
            tag.name.toLowerCase() == tagName) {
          result[tag] = level;
          break;
        }
      }
    }
  }
  return result;
}

/// Application-wide logging facade with enhanced features:
///
/// - Type-safe tags via [LogTag] enum (backward compatible with strings)
/// - Structured logging with context data
/// - Per-tag log level control
/// - Performance timing utilities
/// - Automatic Sentry integration
/// - Configurable verbosity via VERBOSE_LOGGING flag
///
/// ## Basic Usage:
/// ```dart
/// LoggingService.instance.trace('Message', tag: LogTag.rust);
/// LoggingService.instance.info('User action', tag: LogTag.ui, context: {'screen': 'home'});
/// ```
///
/// ## Performance Timing:
/// ```dart
/// final timer = LoggingService.instance.startTimer('rpc_call', tag: LogTag.rust);
/// await performOperation();
/// timer.stop(); // Auto-logs duration
/// ```
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
      printer: _CustomLogPrinter(),
    ),
  );

  static LoggingService get instance => _shared;

  final Logger _logger;

  // Global log level from config (default: info)
  static final Level _globalLevel = _parseLevel(AppConfig.logLevel);

  // Per-tag log level overrides from config
  static final Map<LogTag, Level> _tagLevels =
      _parseTagLevels(AppConfig.logTagLevels);

  /// Log a trace-level message
  void trace(String message, {dynamic tag, Map<String, dynamic>? context}) {
    _log(Level.trace, message, tag: tag, context: context);
  }

  /// Log a debug-level message
  void debug(String message, {dynamic tag, Map<String, dynamic>? context}) {
    _log(Level.debug, message, tag: tag, context: context);
  }

  /// Log an info-level message
  void info(String message, {dynamic tag, Map<String, dynamic>? context}) {
    _log(Level.info, message, tag: tag, context: context);
  }

  /// Log a warning-level message
  void warn(String message, {dynamic tag, Map<String, dynamic>? context}) {
    _log(Level.warning, message, tag: tag, context: context);
  }

  /// Log an error-level message with optional error object and stack trace
  void error(
    String message, {
    dynamic tag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final formatted = _decorate(message, tag, context);
    _logger.e(formatted, error: error, stackTrace: stackTrace);

    // Send to Sentry
    if (error != null && stackTrace != null) {
      // Fire-and-forget; ignore failures.
      // ignore: discarded_futures
      SentryUtil.captureError(
        error,
        stackTrace,
        tag: _tagToString(tag),
        context: context,
      );
    } else {
      SentryUtil.addBreadcrumb(
        category: _tagToString(tag) ?? 'logging',
        message: message,
        data: context,
      );
    }
  }

  /// Start a performance timer
  ///
  /// Returns a [LogTimer] that can be stopped to auto-log the duration.
  ///
  /// Example:
  /// ```dart
  /// final timer = logger.startTimer('operation', tag: LogTag.performance);
  /// await doWork();
  /// timer.stop(context: {'items': 100});
  /// ```
  LogTimer startTimer(String name, {dynamic tag}) {
    return LogTimer._(name, tag ?? LogTag.performance, this);
  }

  /// Create a tagged logger for cleaner per-file usage
  ///
  /// Example:
  /// ```dart
  /// final _log = LoggingService.instance.withTag(LogTag.node);
  /// _log.debug('message');  // Automatically tagged with NODE
  /// ```
  TaggedLogger withTag(dynamic tag) => TaggedLogger._(tag, this);

  void _log(
    Level level,
    String message, {
    dynamic tag,
    Map<String, dynamic>? context,
  }) {
    // Check if this tag/level should be logged
    if (!_shouldLog(level, tag)) {
      return;
    }

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
      case Level.error:
      case Level.fatal:
      case Level.all:
      case Level.off:
      // ignore: deprecated_member_use
      case Level.verbose:
      // ignore: deprecated_member_use
      case Level.wtf:
      // ignore: deprecated_member_use
      case Level.nothing:
        // Handled by error() method or should not log
        break;
    }

    // Add breadcrumb for non-error logs
    if (level.index >= Level.info.index) {
      SentryUtil.addBreadcrumb(
        category: _tagToString(tag) ?? 'logging',
        message: message,
        data: context,
        level: _levelToSentryLevel(level),
      );
    }
  }

  bool _shouldLog(Level level, dynamic tag) {
    // Check tag-specific level override if tag is provided
    if (tag is LogTag && _tagLevels.containsKey(tag)) {
      return level.index >= _tagLevels[tag]!.index;
    }

    // Fall back to global log level
    return level.index >= _globalLevel.index;
  }

  String _decorate(String message, dynamic tag, Map<String, dynamic>? context) {
    // Guard against empty messages
    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      message = '<empty log message>';
      // Add stack trace info in debug mode
      if (kDebugMode) {
        try {
          throw Exception('Empty log detected');
        } catch (_, stack) {
          final frames = stack.toString().split('\n').take(3).join('\n');
          message = '$message\nCalled from:\n$frames';
        }
      }
    } else {
      message = trimmedMessage;
    }

    // Add tag prefix
    final tagStr = _tagToString(tag);
    if (tagStr != null && tagStr.isNotEmpty) {
      message = '[$tagStr] $message';
    }

    // Add context if provided
    if (context != null && context.isNotEmpty) {
      final contextStr =
          context.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      message = '$message {$contextStr}';
    }

    return message;
  }

  String? _tagToString(dynamic tag) {
    if (tag == null) return null;
    if (tag is LogTag) return tag.value;
    if (tag is String) return tag;
    return tag.toString();
  }

  SentryLevel _levelToSentryLevel(Level level) {
    switch (level) {
      case Level.trace:
      case Level.debug:
      // ignore: deprecated_member_use
      case Level.verbose:
        return SentryLevel.debug;
      case Level.info:
        return SentryLevel.info;
      case Level.warning:
        return SentryLevel.warning;
      case Level.error:
      case Level.fatal:
      // ignore: deprecated_member_use
      case Level.wtf:
        return SentryLevel.fatal;
      case Level.all:
      case Level.off:
      // ignore: deprecated_member_use
      case Level.nothing:
        return SentryLevel.info;
    }
  }
}

/// Timer for measuring operation duration
///
/// Created by [LoggingService.startTimer] and stopped by calling [stop()].
class LogTimer {
  LogTimer._(this._name, this._tag, this._logger) : _startTime = DateTime.now();

  final String _name;
  final dynamic _tag;
  final LoggingService _logger;
  final DateTime _startTime;
  bool _stopped = false;

  /// Stop the timer and log the duration
  void stop({Map<String, dynamic>? context}) {
    if (_stopped) {
      if (kDebugMode) {
        print('Warning: LogTimer "$_name" stopped multiple times');
      }
      return;
    }

    _stopped = true;
    final duration = DateTime.now().difference(_startTime);
    final ms = duration.inMilliseconds;

    final enrichedContext = <String, dynamic>{
      'duration_ms': ms,
      ...?context,
    };

    // Choose log level based on duration (slow operations = warning)
    if (ms > 1000) {
      _logger.warn('$_name took ${ms}ms (SLOW)',
          tag: _tag, context: enrichedContext);
    } else if (ms > 500) {
      _logger.info('$_name took ${ms}ms', tag: _tag, context: enrichedContext);
    } else {
      _logger.debug('$_name took ${ms}ms', tag: _tag, context: enrichedContext);
    }
  }

  /// Get elapsed time without stopping timer
  Duration get elapsed => DateTime.now().difference(_startTime);
}

/// Logger wrapper with a pre-bound tag for cleaner per-file usage.
///
/// Usage:
/// ```dart
/// final _log = LoggingService.instance.withTag(LogTag.node);
/// _log.debug('message');  // Automatically tagged with NODE
/// ```
class TaggedLogger {
  final dynamic _tag;
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

  LogTimer startTimer(String name) => _service.startTimer(name, tag: _tag);
}

/// Custom log filter with environment-based filtering
///
/// Level filtering is primarily handled by [LoggingService._shouldLog]
/// using LOG_LEVEL and LOG_TAG_LEVELS config. This filter adds:
/// - Release mode restriction (warning+ only)
/// - Backward compatibility with VERBOSE_LOGGING flag
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In release builds, only log warnings and errors
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }

    // In debug/profile mode, level filtering is handled by _shouldLog
    // using LOG_LEVEL config. Always allow here.
    return true;
  }
}

/// Custom log printer with cleaner format
class _CustomLogPrinter extends LogPrinter {
  _CustomLogPrinter();

  static final _levelEmojis = {
    Level.trace: '[TRACE]',
    Level.debug: '[DEBUG]',
    Level.info: '[INFO]',
    Level.warning: '[WARN] ⚠️',
    Level.error: '[ERROR] ❌',
    Level.fatal: '[FATAL] 💀',
  };

  @override
  List<String> log(LogEvent event) {
    final message = event.message.toString();
    final level = event.level;
    final time = DateTime.now();
    final error = event.error;
    final stackTrace = event.stackTrace;

    final lines = <String>[];

    // Format: HH:mm:ss.SSS EMOJI Message
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';

    final emoji = kReleaseMode ? '' : (_levelEmojis[level] ?? '');
    final prefix = kReleaseMode
        ? '$timeStr [${level.name.toUpperCase()}]'
        : '$timeStr $emoji';

    lines.add('$prefix $message');

    // Add error if present
    if (error != null) {
      lines.add('  Error: $error');
    }

    // Add stack trace if present (only for errors)
    if (stackTrace != null && level.index >= Level.error.index) {
      final frames = stackTrace.toString().split('\n').take(10);
      for (final frame in frames) {
        if (frame.trim().isNotEmpty) {
          lines.add('  $frame');
        }
      }
    }

    return lines;
  }
}

/// Type-safe logging tags to prevent typos and enable autocomplete.
///
/// Usage:
/// ```dart
/// LoggingService.instance.trace('Message', tag: LogTag.node);
/// ```
///
/// Backward compatibility: String tags are still supported.
enum LogTag {
  bootstrap('BOOTSTRAP'),

  /// Riverpod provider state management
  provider('PROVIDER'),

  /// Wallet operations (UTXOs, transactions, assets)
  wallet('WALLET'),

  /// Onboarding flow
  onboarding('ONBOARDING'),

  /// Node status and peers
  node('NODE'),

  /// Application lifecycle
  lifecycle('LIFECYCLE'),

  /// Performance and timing
  performance('PERF'),

  /// Metrics collection and reporting
  metrics('METRICS'),

  /// General/uncategorized
  general('GENERAL'),

  /// App routing
  router('ROUTER'),

  /// Epoch Rewards Provider
  epochRewardsProvider('EPOCH_REWARDS_PROVIDER'),

  /// Produced Blocks Provider
  producedBlocksProvider('PRODUCED_BLOCK_PROVIDER'),

  /// Version checker
  versionCheck('VERSION_CHECK'),

  slotMonitorService('SLOT_MONITOR_SERVICE'),

  /// Settings screens
  settings('SETTINGS');

  const LogTag(this.value);

  /// The string value of the tag for logging
  final String value;

  @override
  String toString() => value;
}
