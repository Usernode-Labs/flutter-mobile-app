import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent toggle for which screen the bottom-nav Dapps tab shows.
///
/// false (default) → the original dApps directory list ([DappsScreen]'s
///                    list mode).
/// true            → a full-bleed WebView pointing at
///                    [AppConfig.dappsTabUrl] (e.g. the Social Vibecoding
///                    hub).
///
/// Flipped by long-pressing the Dapps item in the bottom navigation bar.
/// The value persists across launches via SharedPreferences. First launch
/// always starts on the list view (state defaults to false until the user
/// toggles).
class DappsTabModeNotifier extends Notifier<bool> {
  static const _prefsKey = 'dapps:tab_webview_mode';

  @override
  bool build() {
    // Kick off async load; UI will refresh once the persisted value is
    // available. Default keeps the original list visible on first frame
    // so the user always sees the existing dApps screen before any
    // toggle has happened.
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (stored != null && stored != state) {
        state = stored;
      }
    } catch (_) {
      // Ignore — fall back to default (false).
    }
  }

  Future<void> toggle() async {
    final next = !state;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, next);
    } catch (_) {
      // Ignore persistence failure — in-memory state still flipped.
    }
  }
}

final dappsTabModeProvider =
    NotifierProvider<DappsTabModeNotifier, bool>(DappsTabModeNotifier.new);
