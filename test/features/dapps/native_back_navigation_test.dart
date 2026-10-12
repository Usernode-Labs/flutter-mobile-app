import 'dart:async';

import 'package:crypto_mobile_app/features/dapps/native_back_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a document reset cancels an enable awaiting realm validation',
      () async {
    final validation = Completer<bool>();
    final started = Completer<void>();
    final writes = <bool>[];
    final navigation =
        NativeBackNavigation((enabled) async => writes.add(enabled));
    final enable = navigation.setEnabled(true, canApply: () {
      started.complete();
      return validation.future;
    });
    await started.future;
    final reset = navigation.setEnabled(false);
    validation.complete(true);
    expect(await enable, isFalse);
    expect(await reset, isTrue);
    expect(writes, [false]);
  });

  test('reset follows an in-flight native enable without concurrent writes',
      () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    final writes = <bool>[];
    final navigation = NativeBackNavigation((enabled) async {
      writes.add(enabled);
      if (enabled) {
        started.complete();
        await finish.future;
      }
    });
    final enable = navigation.setEnabled(true);
    await started.future;
    final reset = navigation.setEnabled(false);
    expect(writes, [true]);
    finish.complete();
    await enable;
    await reset;
    expect(writes, [true, false]);
  });

  test('a retired or untrusted realm cannot enable gestures', () async {
    final writes = <bool>[];
    final navigation =
        NativeBackNavigation((enabled) async => writes.add(enabled));
    expect(await navigation.setEnabled(true, canApply: () async => false),
        isFalse);
    expect(writes, isEmpty);
  });

  test('failed native writes do not prevent a later disable', () async {
    final writes = <bool>[];
    final navigation = NativeBackNavigation((enabled) async {
      if (enabled) throw StateError('platform unavailable');
      writes.add(enabled);
    });
    await expectLater(navigation.setEnabled(true), throwsStateError);
    expect(await navigation.setEnabled(false), isTrue);
    expect(writes, [false]);
  });
}
