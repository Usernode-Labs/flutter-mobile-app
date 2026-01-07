import 'package:intl/intl.dart';

abstract final class Utils {
  /// Converts a [BigInt] timestamp to an ISO 8601 UTC string.
  ///
  /// Automatically detects the unit of the timestamp based on digit count:
  /// - 19+ digits: nanoseconds
  /// - 16-18 digits: microseconds
  /// - 13-15 digits: milliseconds
  /// - <13 digits: seconds
  ///
  /// Example:
  /// ```dart
  /// final iso = TimeFormatUtils.formatUtc(BigInt.from(1704067200000));
  /// // Returns: "2024-01-01T00:00:00.000Z"
  /// ```
  static String timestampToUTC(BigInt value) {
    final digits = value.toString().length;
    final BigInt ms;

    if (digits >= 19) {
      // nanoseconds -> milliseconds
      ms = value ~/ BigInt.from(1000000);
    } else if (digits >= 16) {
      // microseconds -> milliseconds
      ms = value ~/ BigInt.from(1000);
    } else if (digits >= 13) {
      // already milliseconds
      ms = value;
    } else {
      // seconds -> milliseconds
      ms = value * BigInt.from(1000);
    }

    return DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true)
        .toIso8601String();
  }

  /// Converts a [BigInt] timestamp to a human-readable relative time string.
  ///
  /// Returns phrases like "just now", "5 minutes ago", "2 hours ago",
  /// "yesterday", "3 days ago", "2 weeks ago", "6 months ago", "1 year ago".
  ///
  /// Example:
  /// ```dart
  /// final ago = TimeFormatUtils.formatTimeAgo(BigInt.from(1704067200000));
  /// // Returns: "2 weeks ago" (depending on current time)
  /// ```
  static String timestampToTimeAgo(BigInt value) {
    final DateTime dt;
    try {
      dt = DateTime.parse(timestampToUTC(value)).toUtc();
    } catch (_) {
      return 'just now';
    }

    final diff = DateTime.now().toUtc().difference(dt);

    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 2) return 'a minute ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 2) return 'an hour ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 2) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    final weeks = diff.inDays ~/ 7;
    if (weeks < 5) return '$weeks week${weeks > 1 ? 's' : ''} ago';

    final months = diff.inDays ~/ 30;
    if (months < 12) return '$months month${months > 1 ? 's' : ''} ago';

    final years = diff.inDays ~/ 365;
    return '$years year${years > 1 ? 's' : ''} ago';
  }

  static String shortenID(String s, {int head = 12, int tail = 12}) {
    if (s.length <= head + tail + 1) return s;
    return '${s.substring(0, head)}…${s.substring(s.length - tail)}';
  }

  static String formatBigInt(
    BigInt value,
  ) {
    try {
      return NumberFormat('#,###', 'en_US').format(value.toInt());
    } catch (_) {
      return value.toString();
    }
  }
}
