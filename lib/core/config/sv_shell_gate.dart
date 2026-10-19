import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

/// Whether the SV shell has ever loaded on this install: the first-launch
/// gate `SvShellScreen` keeps over its WebView until the first load succeeds,
/// after which the page's service worker owns offline.
///
/// ## Read synchronously, or every launch shows the gate
///
/// [passed] is a plain field mirrored from SharedPreferences by [init] during
/// bootstrap, for the same reason `AppearanceStorage.scheme` is: the shell
/// decides on its first frame whether to create the WebView. It used to read
/// the flag itself, and until that await resolved it had no answer, so every
/// launch showed "Connecting to Homeroom…" and created no WebView for its
/// first frames, including launches years after the gate had passed.
class SvShellGateStorage {
  SvShellGateStorage._();

  static const _key = 'sv_shell_first_load_ok';

  /// Whether SV has ever rendered on this install. False until [init] has
  /// read a stored true, and on a fresh install, where the gate is the right
  /// answer.
  static bool passed = false;

  /// Mirror the persisted flag into [passed]. Call once during bootstrap,
  /// before the first frame.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      passed = prefs.getBool(_key) ?? false;
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'sv_shell_gate_load');
    }
  }

  /// Record that SV has rendered. One-way: nothing ever closes the gate
  /// again.
  static Future<void> markPassed() async {
    passed = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'sv_shell_gate_save');
    }
  }
}
