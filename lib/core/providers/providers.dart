import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/src/rust/mobile_api.dart' as native;
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';
import 'package:flutter/material.dart';

// Build environment from Rust bindings
final buildEnvProvider = Provider((ref) => native.nativeBuildInfo());

// Theme mode controller with persistence
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _init();
  }

  Future<void> _init() async {
    final saved = await ThemeModeStorage.load();
    state = saved;
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
