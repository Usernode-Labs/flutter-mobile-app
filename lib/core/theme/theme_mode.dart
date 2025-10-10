import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

class ThemeModeStorage {
  static const _key = 'app:theme_mode';

  static Future<ThemeMode> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      switch (v) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'theme_load');
      return ThemeMode.system;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_key, v);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'theme_save');
    }
  }
}

