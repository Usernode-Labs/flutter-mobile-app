import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

/// The appearance the SV web shell last resolved to, published over the
/// native bridge (`setAppearance`) and persisted so the NEXT cold launch can
/// open in it.
///
/// ## Why this exists
///
/// The launch screen is painted before the WebView has loaded anything, so
/// the colour it needs is needed before any web code can tell us what it is.
/// SV's theme lives in the WebView's localStorage and ours in
/// SharedPreferences (`app:theme_mode`); nothing carried a value between
/// them, so we fell back to the OS preference — and got it wrong for
/// everyone who had picked Dark in SV on a light-mode phone, painting a
/// full-screen white frame ahead of a near-black shell on every cold launch.
///
/// The fix is to remember. SV publishes its resolved appearance on every
/// boot and every theme change; we store it, and open the next launch in it.
///
/// ## Read synchronously, or it does not work
///
/// [scheme] and [background] are plain fields, mirrored from
/// SharedPreferences by [init] during bootstrap, for the same reason
/// `DebugModeStorage.isEnabled` is a plain `bool`: the launch path cannot
/// `await`. A value fetched after the first frame has already lost — it
/// would trade the white flash for a light-to-dark repaint, which is the
/// same bug wearing a different colour.
///
/// Both are null until SV has published at least once. That is a fresh
/// install and every build older than the `setAppearance` capability, and
/// the caller's fallback for it is the OS preference — right more often
/// than not, and exactly the behaviour that shipped before this.
class AppearanceStorage {
  AppearanceStorage._();

  static const _schemeKey = 'app:sv_appearance_scheme';
  static const _backgroundKey = 'app:sv_appearance_background';

  /// The appearance SV resolved to, or null if it has never published.
  ///
  /// Already resolved: SV folds its own tri-state mode (`light` / `dark` /
  /// `system`) against the OS preference before publishing, so this is a
  /// straight two-value answer and must NOT be re-resolved here.
  static Brightness? scheme;

  /// The page ground SV actually paints, or null when it did not send one
  /// (or has never published). Callers fall back to their own colour for
  /// [scheme] — the scheme is the part that stops the flash; this only
  /// makes the seam invisible rather than merely dark.
  static Color? background;

  /// [scheme] expressed as a [ThemeMode], or null when SV has never
  /// published — in which case the caller keeps whatever it used before.
  static ThemeMode? get themeMode => switch (scheme) {
        Brightness.dark => ThemeMode.dark,
        Brightness.light => ThemeMode.light,
        null => null,
      };

  /// Mirror the persisted values into the synchronous fields. Call once
  /// during bootstrap, before the first frame.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedScheme = prefs.getString(_schemeKey);
      scheme = switch (storedScheme) {
        'dark' => Brightness.dark,
        'light' => Brightness.light,
        _ => null,
      };
      final storedBackground = prefs.getInt(_backgroundKey);
      background = storedBackground == null ? null : Color(storedBackground);
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'appearance_load');
    }
  }

  /// Store what SV just published. Idempotent and last-write-wins: writing
  /// the value we already hold changes nothing, so a republish on every
  /// boot costs a no-op rather than a flicker.
  ///
  /// A null [background] CLEARS the stored colour rather than retaining a
  /// stale one — SV omits the field only when it could not read its own
  /// ground, and a colour from a previous theme would be worse than none.
  static Future<void> save({
    required Brightness scheme,
    Color? background,
  }) async {
    AppearanceStorage.scheme = scheme;
    AppearanceStorage.background = background;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _schemeKey,
        scheme == Brightness.dark ? 'dark' : 'light',
      );
      if (background == null) {
        await prefs.remove(_backgroundKey);
      } else {
        await prefs.setInt(_backgroundKey, background.toARGB32());
      }
    } catch (e, st) {
      await SentryUtil.captureError(e, st, tag: 'appearance_save');
    }
  }

  /// Parse a `#rrggbb` string as SV sends it. Returns null for anything
  /// else, including the `#rgb` short form and any alpha — the bridge
  /// wrapper already validates the shape, and a launch background is always
  /// fully opaque.
  static Color? parseBackground(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(value.trim());
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }
}
