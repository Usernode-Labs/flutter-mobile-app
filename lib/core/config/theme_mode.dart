import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

/// Persistence and process-wide cache for the app's own theme mode.
///
/// [cached] is a plain field, mirrored from SharedPreferences by [init]
/// during bootstrap, for the same reason `DebugModeStorage.isEnabled` is a
/// plain `bool`: it is read on the launch path, which cannot `await`.
///
/// It used to be read only asynchronously, so `ThemeModeController` started
/// every launch at [ThemeMode.system] and corrected itself once prefs
/// resolved — a visible light-to-dark repaint on the splash for anyone whose
/// stored mode differed from their phone's.
class ThemeModeStorage {
  ThemeModeStorage._();

  static const _key = 'app:theme_mode';

  /// Synchronously-readable cache of the persisted mode. [ThemeMode.system]
  /// until [init] or [load] resolves the stored value, which is also the
  /// stored default.
  static ThemeMode cached = ThemeMode.system;

  /// Load the persisted mode into [cached]. Call once during bootstrap.
  static Future<void> init() async {
    cached = await load();
  }

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      cached = switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return cached;
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'theme_load');
      return cached;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    cached = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key,
          switch (mode) {
            ThemeMode.light => 'light',
            ThemeMode.dark => 'dark',
            ThemeMode.system => 'system',
          });
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'theme_save');
    }
  }
}
