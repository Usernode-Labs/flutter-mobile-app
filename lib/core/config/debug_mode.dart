import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

/// Persistence and process-wide cache for the user-facing **Debug Mode** flag.
///
/// Debug Mode is off by default and, when enabled, opts the app into capturing
/// HTTP traffic into an in-memory buffer (see `HttpDebugLogStore`).
///
/// The flag is read on the HTTP hot path by `LoggingHttpClient`, which cannot
/// `await` SharedPreferences per request. To keep that read synchronous, the
/// last-known value is mirrored into [isEnabled] (a plain `bool`). Call [init]
/// once at startup so the cache reflects the persisted value before any request
/// is made; [save] keeps it in sync afterwards.
class DebugModeStorage {
  DebugModeStorage._();

  static const _key = 'app:debug_mode';

  /// Synchronously-readable cache of the persisted flag. Defaults to `false`
  /// until [init] or [load] resolves the stored value.
  static bool isEnabled = false;

  /// Load the persisted flag into [isEnabled]. Call once during bootstrap.
  static Future<void> init() async {
    isEnabled = await load();
  }

  static Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isEnabled = prefs.getBool(_key) ?? false;
      return isEnabled;
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'debug_mode_load');
      return isEnabled;
    }
  }

  static Future<void> save(bool enabled) async {
    isEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'debug_mode_save');
    }
  }
}
