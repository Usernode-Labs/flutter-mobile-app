// The cold-launch white flash.
//
// The launch screen is painted before the WebView has loaded anything, so
// the colour it needs is needed before any web code can say what it is. SV's
// theme lives in the WebView's localStorage and ours in SharedPreferences;
// nothing carried a value between them, so we fell back to the OS preference
// and painted a full-screen WHITE frame ahead of a near-black shell for
// everyone who had picked Dark in SV on a light-mode phone.
//
// These cover the remembering half. The XML half — the iOS storyboard and
// the Android launch drawables — is at the bottom, because a literal white
// in either is the exact regression this change removes.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/theme_mode.dart';
import 'package:crypto_mobile_app/core/providers/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppearanceStorage.scheme = null;
    AppearanceStorage.background = null;
    ThemeModeStorage.cached = ThemeMode.system;
  });

  group('parseBackground', () {
    test('accepts the #rrggbb form SV sends', () {
      expect(
        AppearanceStorage.parseBackground('#0b0b0c'),
        const Color(0xFF0B0B0C),
      );
      expect(
        AppearanceStorage.parseBackground('#EAEAEA'),
        const Color(0xFFEAEAEA),
      );
      expect(
        AppearanceStorage.parseBackground('  #eaeaea  '),
        const Color(0xFFEAEAEA),
      );
    });

    test('rejects everything else rather than guessing', () {
      // A launch background is always fully opaque, and the bridge wrapper
      // already validates the shape — anything that gets here malformed is
      // better dropped than approximated.
      for (final bad in <Object?>[
        null,
        '',
        '#fff',
        '0b0b0c',
        '#0b0b0cff',
        'rgb(11,11,12)',
        'black',
        11,
      ]) {
        expect(
          AppearanceStorage.parseBackground(bad),
          isNull,
          reason: 'should reject $bad',
        );
      }
    });
  });

  group('storage', () {
    test('is null until SV has published once', () async {
      await AppearanceStorage.init();
      expect(AppearanceStorage.scheme, isNull);
      expect(AppearanceStorage.background, isNull);
      // Which is what a fresh install and every pre-setAppearance build
      // gets, and the caller's cue to fall back to the OS preference.
      expect(AppearanceStorage.themeMode, isNull);
    });

    test('round-trips a published appearance across a relaunch', () async {
      await AppearanceStorage.save(
        scheme: Brightness.dark,
        background: const Color(0xFF0B0B0C),
      );

      // Simulate the next cold launch: fields cleared, only prefs survive.
      AppearanceStorage.scheme = null;
      AppearanceStorage.background = null;
      await AppearanceStorage.init();

      expect(AppearanceStorage.scheme, Brightness.dark);
      expect(AppearanceStorage.background, const Color(0xFF0B0B0C));
      expect(AppearanceStorage.themeMode, ThemeMode.dark);
    });

    test('a later publish without a colour CLEARS the stored one', () async {
      await AppearanceStorage.save(
        scheme: Brightness.dark,
        background: const Color(0xFF0B0B0C),
      );
      // SV omits `background` only when it could not read its own ground.
      // Keeping the dark colour under a light scheme would be worse than
      // having none and falling back to the theme.
      await AppearanceStorage.save(scheme: Brightness.light);

      AppearanceStorage.scheme = null;
      AppearanceStorage.background = null;
      await AppearanceStorage.init();

      expect(AppearanceStorage.scheme, Brightness.light);
      expect(AppearanceStorage.background, isNull);
    });

    test('re-saving the same value is a no-op, not a flicker', () async {
      await AppearanceStorage.save(
        scheme: Brightness.dark,
        background: const Color(0xFF0B0B0C),
      );
      final scheme = AppearanceStorage.scheme;
      final background = AppearanceStorage.background;
      await AppearanceStorage.save(
        scheme: Brightness.dark,
        background: const Color(0xFF0B0B0C),
      );
      expect(AppearanceStorage.scheme, scheme);
      expect(AppearanceStorage.background, background);
    });
  });

  group('the theme mode the first frame is built with', () {
    test('follows SV once it has published', () {
      ThemeModeStorage.cached = ThemeMode.light;
      AppearanceStorage.scheme = Brightness.dark;
      // SV owns the theme control the user actually touches, and its
      // resolved appearance is what the WebView is about to paint.
      expect(ThemeModeController.initialThemeMode, ThemeMode.dark);
    });

    test("falls back to the app's own stored mode before that", () {
      ThemeModeStorage.cached = ThemeMode.dark;
      AppearanceStorage.scheme = null;
      expect(ThemeModeController.initialThemeMode, ThemeMode.dark);
    });

    test('is resolved SYNCHRONOUSLY, before any await', () async {
      // The bug's second half: this used to start at ThemeMode.system and
      // correct itself once SharedPreferences resolved, so a stored dark
      // mode on a light phone repainted the splash a beat after it
      // appeared. Bootstrap primes both caches, and the getter must read
      // them without awaiting anything.
      SharedPreferences.setMockInitialValues({'app:theme_mode': 'dark'});
      await ThemeModeStorage.init();
      expect(ThemeModeController.initialThemeMode, ThemeMode.dark);
    });
  });

  group('the native launch surfaces carry no literal white', () {
    // Every one of these painted white on a cold launch, regardless of
    // appearance. They are asserted as file content because there is no
    // other way to catch a re-hardcoded colour: nothing at runtime reads
    // them back.

    test('the iOS launch storyboard uses the adaptive colour asset', () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();
      expect(
        storyboard,
        contains('<color key="backgroundColor" name="LaunchBackground"/>'),
      );
      // The literal it replaced: red/green/blue all 1, i.e. pure white,
      // with no dark variant possible.
      expect(
        storyboard,
        isNot(contains('red="1" green="1" blue="1"')),
        reason: 'the launch screen must not paint a fixed white again',
      );

      final colorset = File(
        'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
      ).readAsStringSync();
      expect(colorset, contains('"appearance" : "luminosity"'));
      expect(colorset, contains('"value" : "dark"'));
      // The two grounds SV paints, so the seam between the launch screen
      // and the page is invisible rather than merely dark.
      expect(colorset, contains('0xEA'));
      expect(colorset, contains('0x0C'));
    });

    test('the Android launch drawables read the theme, not a colour', () {
      for (final path in [
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-v21/launch_background.xml',
      ]) {
        final xml = File(path).readAsStringSync();
        expect(xml, contains('?android:colorBackground'), reason: path);
        expect(xml, isNot(contains('@android:color/white')), reason: path);
      }
    });

    test('both Android appearances pin colorBackground to the SV ground', () {
      // Stock Theme.Light is pure white and Theme.Black pure black; the
      // shell paints #eaeaea and #0b0b0c. Without these the launch window
      // is a visibly different surface from the page it introduces.
      for (final path in [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final xml = File(path).readAsStringSync();
        expect(
          RegExp(
            r'android:colorBackground">@color/launch_background<',
          ).allMatches(xml).length,
          2,
          reason: '$path must pin it on LaunchTheme AND NormalTheme',
        );
      }
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('#eaeaea'),
      );
      expect(
        File(
          'android/app/src/main/res/values-night/colors.xml',
        ).readAsStringSync(),
        contains('#0b0b0c'),
      );
    });
  });

  test('setAppearance is advertised, and advertised as unprivileged', () {
    // SV feature-detects the capability string before it will call; and the
    // whole point is that it works before sign-in, so it must NOT be behind
    // the trusted-origin lease every other settings method uses.
    final dispatch = File(
      'lib/features/dapps/bridge/dapp_bridge_dispatch.dart',
    ).readAsStringSync();
    expect(dispatch, contains("'setAppearance'"));

    final handler = File(
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
    ).readAsStringSync();
    final body = handler.substring(handler.indexOf('_handleSetAppearance'));
    final end = body.indexOf('\n  }\n');
    expect(
      body.substring(0, end),
      isNot(contains('_requireTrustedChromeOrigin')),
      reason: 'gating this on a privileged lease removes the whole feature: '
          'the launch it fixes is the one before sign-in',
    );
    expect(
      body.substring(0, end),
      isNot(contains('_revalidatePrivilegedBridgeLease')),
    );
  });
}
