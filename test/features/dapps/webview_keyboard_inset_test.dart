import 'package:crypto_mobile_app/features/dapps/webview_keyboard_inset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'iOS leaves the web view its full height; WebKit makes room for the keys',
      () {
    expect(webViewResizesForKeyboard(TargetPlatform.iOS), isFalse);
  });

  test('Android still ends the web view at the keyboard', () {
    expect(webViewResizesForKeyboard(TargetPlatform.android), isTrue);
  });
}
