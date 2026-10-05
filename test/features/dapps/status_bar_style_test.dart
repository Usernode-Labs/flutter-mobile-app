import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/dapps/status_bar_style.dart';

void main() {
  group('statusBarStyleFor', () {
    test('without an override the ground follows the theme', () {
      expect(
        statusBarStyleFor(themeBrightness: Brightness.dark),
        SystemUiOverlayStyle.light,
      );
      expect(
        statusBarStyleFor(themeBrightness: Brightness.light),
        SystemUiOverlayStyle.dark,
      );
    });

    test('the page tone wins over the theme, in both directions', () {
      // A dark fullscreen preview over the light shell.
      expect(
        statusBarStyleFor(
          themeBrightness: Brightness.light,
          toneOverride: StatusBarTone.dark,
        ),
        SystemUiOverlayStyle.light,
      );
      // A light app open on the dark shell.
      expect(
        statusBarStyleFor(
          themeBrightness: Brightness.dark,
          toneOverride: StatusBarTone.light,
        ),
        SystemUiOverlayStyle.dark,
      );
    });

    test('the tone names the ground, so dark takes light glyphs', () {
      final style = statusBarStyleFor(
        themeBrightness: Brightness.light,
        toneOverride: StatusBarTone.dark,
      );
      expect(style.statusBarIconBrightness, Brightness.light);
      // iOS reads the bar's own brightness: a dark bar has light text.
      expect(style.statusBarBrightness, Brightness.dark);
    });
  });

  group('parseStatusBarToneArgs', () {
    test('reads the two tones', () {
      expect(parseStatusBarToneArgs({'tone': 'dark'}), StatusBarTone.dark);
      expect(parseStatusBarToneArgs({'tone': 'light'}), StatusBarTone.light);
    });

    test('null clears, and so does an absent tone', () {
      // JSON.stringify({tone: undefined}) sends {}.
      expect(parseStatusBarToneArgs({'tone': null}), isNull);
      expect(parseStatusBarToneArgs(<String, dynamic>{}), isNull);
    });

    test('anything else is an error, not a guess', () {
      for (final bad in <Object?>[
        null,
        'dark',
        {'tone': 'Dark'},
        {'tone': 'black'},
        {'tone': ''},
        {'tone': true},
        {'tone': 1},
      ]) {
        expect(
          () => parseStatusBarToneArgs(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('bridge wiring', () {
    final dispatch = File(
      'lib/features/dapps/bridge/dapp_bridge_dispatch.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/dapps/bridge/dapp_bridge_settings.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/dapps/dapp_webview_screen.dart',
    ).readAsStringSync();

    String handlerBody() {
      final start = settings.indexOf('Future<void> _handleSetStatusBarTone(');
      expect(start, greaterThanOrEqualTo(0));
      return settings.substring(start, settings.indexOf('\n  }\n', start));
    }

    test('advertised as a capability and routed to its handler', () {
      expect(dispatch, contains("    'setStatusBarTone',\n"));
      expect(
        dispatch,
        contains(
          "if (method == 'setStatusBarTone') {\n"
          '      await _handleSetStatusBarTone(id, payload);',
        ),
      );
    });

    test('unprivileged, like setAppearance', () {
      // The SV shell on a staging origin, and before sign-in, has no
      // privileged lease, and the preview's bar needs fixing there too.
      final body = handlerBody();
      expect(body, isNot(contains('_requireTrustedChromeOrigin')));
      expect(body, isNot(contains('_revalidatePrivilegedBridgeLease')));
      expect(body, isNot(contains('_resolveClaimedSessionOperation')));
    });

    test('never persisted', () {
      final body = handlerBody();
      expect(body, isNot(contains('AppearanceStorage')));
      expect(body, isNot(contains('SharedPreferences')));
      expect(body, isNot(contains('themeModeProvider')));
    });

    test('the override drives the status bar, and a new document clears it',
        () {
      expect(
        screen,
        contains(
          'value: statusBarStyleFor(\n'
          '        themeBrightness: colors.brightness,\n'
          '        toneOverride: _statusBarTone,\n'
          '      ),',
        ),
      );
      final pageStarted = screen.substring(
        screen.indexOf('onPageStarted: (_) {'),
        screen.indexOf('onPageFinished: (_) {'),
      );
      expect(pageStarted, contains('_clearStatusBarTone();'));
    });
  });
}
