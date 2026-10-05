import 'package:flutter/services.dart';

/// Tone of the page ground under the status bar, as the web reports it with
/// the `setStatusBarTone` bridge call. It names the GROUND, not the glyphs,
/// with the same meaning as the web's `data-app-tone`: a `dark` ground takes
/// light glyphs.
enum StatusBarTone { light, dark }

/// Reads `setStatusBarTone`'s args, `{tone: 'light' | 'dark' | null}`. Null
/// clears the override. An absent `tone` is null too, because
/// `JSON.stringify` drops an undefined property. Anything else throws a
/// [FormatException] whose message is the bridge error.
StatusBarTone? parseStatusBarToneArgs(Object? args) {
  if (args is! Map) {
    throw const FormatException("args must be {tone: 'light' | 'dark' | null}");
  }
  return switch (args['tone']) {
    null => null,
    'light' => StatusBarTone.light,
    'dark' => StatusBarTone.dark,
    _ => throw const FormatException(
        "args.tone must be 'light', 'dark' or null",
      ),
  };
}

/// Status-bar glyph style for the screen hosting the web page.
///
/// [toneOverride] is what the page last said sits under the status bar (for
/// example a dark fullscreen preview over a light shell), and wins. Without
/// one the ground follows the app's resolved [themeBrightness], which the web
/// shell keeps in step through `setAppearance`.
SystemUiOverlayStyle statusBarStyleFor({
  required Brightness themeBrightness,
  StatusBarTone? toneOverride,
}) {
  final darkGround = switch (toneOverride) {
    StatusBarTone.dark => true,
    StatusBarTone.light => false,
    null => themeBrightness == Brightness.dark,
  };
  return darkGround ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
}
