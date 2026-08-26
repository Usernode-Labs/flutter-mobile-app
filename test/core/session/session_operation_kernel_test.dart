import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/src/session_lifecycle/session_operation_kernel.dart';

final _identityA = SessionIdentityProjection.ready(
  nativeRevision: '1',
  participantId: 1,
  accountId: 'account-a',
  address: 'address-a',
);

final _identityB = SessionIdentityProjection.ready(
  nativeRevision: '2',
  participantId: 2,
  accountId: 'account-b',
  address: 'address-b',
);

void main() {
  test('run admits before body and close rejects new work synchronously',
      () async {
    final harness = SessionOperationKernelTestHarness(_identityA);
    addTearDown(harness.dispose);
    final runnerA = harness.view.current.operations;
    final operationRelease = Completer<void>();
    final effectRelease = Completer<void>();
    late SessionOperation operation;
    var bodyEntered = false;

    final running = runnerA.run<void>((admitted) {
      bodyEntered = true;
      operation = admitted;
      return operationRelease.future;
    });
    expect(bodyEntered, isTrue);

    final replacement = harness.replaceWith(_identityB);
    var rejectedBodyEntered = false;
    expect(
      () => runnerA.run<void>((_) {
        rejectedBodyEntered = true;
      }),
      throwsA(isA<SessionAdmissionClosedException>()),
    );
    expect(rejectedBodyEntered, isFalse);

    // An operation admitted before close may still acquire the effect needed
    // to finish, but it may not register new child work after close.
    final effect = harness.effects.run<void>(
      operation,
      () => effectRelease.future,
    );
    expect(
      () => operation.runChild<void>((_) {}),
      throwsA(isA<SessionAdmissionClosedException>()),
    );

    operationRelease.complete();
    effectRelease.complete();
    await Future.wait([running, effect, replacement]);
  });

  test('drain waits for registered children and independently counted effects',
      () async {
    final harness = SessionOperationKernelTestHarness(_identityA);
    addTearDown(harness.dispose);
    final childRelease = Completer<void>();
    final effectRelease = Completer<void>();
    late SessionOperation operation;
    late Future<void> child;
    late Future<void> effect;

    final parent = harness.view.current.operations.run<void>((admitted) {
      operation = admitted;
      child = admitted.runChild<void>((_) => childRelease.future);
      effect = harness.effects.run<void>(
        admitted,
        () => effectRelease.future,
      );
    });
    final replacement = harness.replaceWith(_identityB);

    childRelease.complete();
    await child;
    await parent;
    expect(harness.view.current.identity.nativeRevision, '1');

    effectRelease.complete();
    await effect;
    await replacement;
    expect(harness.view.current.identity.nativeRevision, '2');

    expect(
      () => harness.effects.run<void>(operation, () {}),
      throwsA(isA<SessionOperationExpiredException>()),
    );
  });

  test('a retired runner stays revoked after its successor opens', () async {
    final harness = SessionOperationKernelTestHarness(_identityA);
    addTearDown(harness.dispose);
    final runnerA = harness.view.current.operations;

    await harness.replaceWith(_identityB);

    expect(
      () => runnerA.run<void>((_) {}),
      throwsA(isA<SessionAdmissionClosedException>()),
    );
    expect(
      await harness.view.current.operations.run((_) => 'successor'),
      'successor',
    );
  });

  test('successor swaps after drain and before its single notification',
      () async {
    final harness = SessionOperationKernelTestHarness(_identityA);
    addTearDown(harness.dispose);
    final releaseA = Completer<void>();
    final runningA =
        harness.view.current.operations.run<void>((_) => releaseA.future);
    final notifications = <String>[];
    final subscription = harness.view.changes.listen((published) {
      expect(identical(harness.view.current, published), isTrue);
      notifications.add(published.identity.nativeRevision);
    });
    addTearDown(subscription.cancel);

    final replacement = harness.replaceWith(_identityB);
    expect(harness.view.current.identity.nativeRevision, '1');
    expect(notifications, isEmpty);

    releaseA.complete();
    await runningA;
    await replacement;

    expect(harness.view.current.identity.nativeRevision, '2');
    expect(notifications, ['2']);
  });
}
