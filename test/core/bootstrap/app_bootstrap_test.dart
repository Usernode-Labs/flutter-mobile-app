import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bootstrap initializes only inert process services and restricted Rust',
      () async {
    final source = await File(
      'lib/core/bootstrap/app_bootstrap.dart',
    ).readAsString();

    expect(source, contains('await AppSleepStateStore.load()'));
    expect(source, contains('await RustLib.init()'));
    expect(source, isNot(contains('RustBackendService')));
    expect(source, isNot(contains('identityProvider')));
    expect(source, isNot(contains('SessionController')));
  });
}
