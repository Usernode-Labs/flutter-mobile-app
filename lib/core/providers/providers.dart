import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/src/rust/mobile_api.dart' as native;
import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:flutter/material.dart';

// Build environment from Rust bindings
final buildEnvProvider = Provider((ref) => native.nativeBuildInfo());

// Theme mode controller with persistence.
//
// SEEDED SYNCHRONOUSLY, which is the point. This used to start at
// ThemeMode.system and correct itself once SharedPreferences resolved, so
// anyone whose appearance differed from their phone's watched the splash
// repaint a beat after it appeared — the white-flash bug's second half.
// AppBootstrap primes both caches before the first frame, so the first build
// already has the right answer.
//
// SV's published appearance WINS over the app's own stored mode. The app is
// a shell around the SV web app: SV owns the theme control the user actually
// touches, and its resolved appearance is what the WebView is about to
// paint. `app:theme_mode` stays the fallback for a fresh install and for
// every launch before SV has published once (see AppearanceStorage).
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(initialThemeMode) {
    _init();
  }

  static ThemeMode get initialThemeMode =>
      AppearanceStorage.themeMode ?? ThemeModeStorage.cached;

  Future<void> _init() async {
    await ThemeModeStorage.load();
    state = initialThemeMode;
  }

  /// Adopt the appearance SV just published, so the native surfaces around
  /// the WebView — the first-launch gate, the scaffold behind the page —
  /// match it without waiting for a relaunch.
  void adoptPublishedAppearance() {
    state = initialThemeMode;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController();
});

// Debug mode controller with persistence. When enabled, the app captures HTTP
// traffic into [HttpDebugLogStore] (off by default).
class DebugModeController extends StateNotifier<bool> {
  DebugModeController() : super(DebugModeStorage.isEnabled) {
    _init();
  }

  Future<void> _init() async {
    state = await DebugModeStorage.load();
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    await DebugModeStorage.save(enabled);
  }
}

final debugModeProvider =
    StateNotifierProvider<DebugModeController, bool>((ref) {
  return DebugModeController();
});

/// Exposes the in-memory HTTP debug log buffer to the viewer UI.
final httpDebugLogStoreProvider =
    Provider<HttpDebugLogStore>((ref) => HttpDebugLogStore.instance);
