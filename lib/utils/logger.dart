import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Lightweight debug logger.
///
/// - Only prints in debug/profile (kDebugMode || kProfileMode)
/// - Prefixes messages with a short tag and timestamp
class Log {
  static bool get _enabled => kDebugMode || kProfileMode;

  static String _ts() {
    final now = DateTime.now();
    final two = (int n) => n.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.$ms';
  }

  static void d(String tag, String message) {
    if (_enabled) debugPrint('[D ${_ts()}][$tag] $message');
  }

  static void i(String tag, String message) {
    if (_enabled) debugPrint('[I ${_ts()}][$tag] $message');
  }

  static void w(String tag, String message) {
    if (_enabled) debugPrint('[W ${_ts()}][$tag] $message');
  }

  static void e(String tag, String message, [Object? error, StackTrace? st]) {
    if (_enabled) {
      debugPrint('[E ${_ts()}][$tag] $message');
      if (error != null) debugPrint('  error: $error');
      if (st != null) debugPrint('  stack: $st');
    }
  }
}

