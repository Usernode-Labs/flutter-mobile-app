import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('headless recovery has no UI session graph or activation path', () {
    final source = File('lib/main.dart').readAsStringSync();
    final start = source.indexOf('Future<void> headlessMain()');
    final end = source.indexOf('class AppRuntimeRoot', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final headless = source.substring(start, end);

    expect(headless, contains('readBackgroundRuntimeAuthority'));
    expect(headless, contains('recoverNode'));
    expect(headless, isNot(contains('AppBootstrap')));
    expect(headless, isNot(contains('ProviderContainer')));
    expect(headless, isNot(contains('SessionController')));
    expect(headless, isNot(contains('runApp')));
    expect(headless, isNot(contains('completeLogin')));
  });
}
