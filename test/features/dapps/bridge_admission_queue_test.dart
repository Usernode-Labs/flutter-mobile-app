import 'dart:async';

import 'package:crypto_mobile_app/features/dapps/bridge_admission_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('later admission cannot overtake an earlier session fence', () async {
    final queue = BridgeAdmissionQueue();
    final firstEntered = Completer<void>();
    final releaseFirst = Completer<void>();
    var secondEntered = false;
    final order = <String>[];

    final first = queue.run(() async {
      order.add('handoff-start');
      firstEntered.complete();
      await releaseFirst.future;
      order.add('handoff-fenced');
      return 'handoff';
    });
    await firstEntered.future;

    final second = queue.run(() async {
      secondEntered = true;
      order.add('wallet-admitted');
      return 'wallet';
    });
    await Future<void>.delayed(Duration.zero);

    expect(secondEntered, isFalse);
    releaseFirst.complete();
    expect(await Future.wait([first, second]), ['handoff', 'wallet']);
    expect(order, ['handoff-start', 'handoff-fenced', 'wallet-admitted']);
  });

  test('a failed admission releases the next request', () async {
    final queue = BridgeAdmissionQueue();

    final failed = queue.run<void>(() async {
      throw StateError('denied');
    });
    final next = queue.run(() async => 'admitted');

    await expectLater(failed, throwsStateError);
    expect(await next, 'admitted');
  });
}
