import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/bootstrap/app_bootstrap.dart';

void main() {
  test('native events are released after cold-boot recovery is reconciled',
      () async {
    final calls = <String>[];

    final restored = await AppBootstrap.settleNativeRecoveryBeforeReady(
      reconcile: () async => calls.add('reconcile'),
      failClosed: (_, __) async => calls.add('failClosed'),
      markReady: () async => calls.add('ready'),
    );

    expect(restored, isTrue);
    expect(calls, ['reconcile', 'ready']);
  });

  test('reconciliation failure invalidates authority before releasing events',
      () async {
    final calls = <String>[];
    final failure = StateError('cold boot failed');

    final restored = await AppBootstrap.settleNativeRecoveryBeforeReady(
      reconcile: () async {
        calls.add('reconcile');
        throw failure;
      },
      failClosed: (error, _) async {
        expect(error, same(failure));
        calls.add('failClosed');
      },
      markReady: () async => calls.add('ready'),
    );

    expect(restored, isFalse);
    expect(calls, ['reconcile', 'failClosed', 'ready']);
  });

  test('native events remain blocked when fail-closed invalidation fails',
      () async {
    var markedReady = false;

    await expectLater(
      AppBootstrap.settleNativeRecoveryBeforeReady(
        reconcile: () async => throw StateError('cold boot failed'),
        failClosed: (_, __) async => throw StateError('invalidation failed'),
        markReady: () async => markedReady = true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'invalidation failed',
        ),
      ),
    );
    expect(markedReady, isFalse);
  });
}
