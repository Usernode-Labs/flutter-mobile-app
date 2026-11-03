import 'package:crypto_mobile_app/features/dapps/webview_system_bar_insets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('webViewSystemBarInsetsFor', () {
    const bars = EdgeInsets.only(top: 48, bottom: 24);

    test('hands Android the status and navigation bar heights', () {
      expect(
        webViewSystemBarInsetsFor(
          TargetPlatform.android,
          viewPadding: bars,
          padding: bars,
        ),
        const WebViewSystemBarInsets(top: 48, bottom: 24),
      );
    });

    test('leaves iOS to its own env() values', () {
      expect(
        webViewSystemBarInsetsFor(
          TargetPlatform.iOS,
          viewPadding: bars,
          padding: bars,
        ),
        isNull,
      );
    });

    test('drops the bottom while the keyboard is up, keeps the top', () {
      expect(
        webViewSystemBarInsetsFor(
          TargetPlatform.android,
          viewPadding: bars,
          padding: const EdgeInsets.only(top: 48),
        ),
        const WebViewSystemBarInsets(top: 48, bottom: 0),
      );
    });
  });

  group('webViewSystemBarInsetsScript', () {
    test('writes both variables as pixel lengths', () {
      final script = webViewSystemBarInsetsScript(
        const WebViewSystemBarInsets(top: 47.619, bottom: 24),
      );
      expect(script, contains('"--un-safe-inset-top":"47.62px"'));
      expect(script, contains('"--un-safe-inset-bottom":"24.00px"'));
    });

    test('a zero clears the variable so the env() fallback decides', () {
      final script = webViewSystemBarInsetsScript(
        const WebViewSystemBarInsets(top: 48, bottom: 0),
      );
      expect(script, contains('"--un-safe-inset-bottom":null'));
      expect(script, contains('removeProperty'));
    });
  });
}
