import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/services/identity_runtime_restart_service.dart';

void main() {
  final service = IdentityRuntimeRestartService.instance;

  setUp(service.resetForTesting);
  tearDown(service.resetForTesting);

  test('declines a restart when no interactive runtime host is registered', () {
    expect(service.request(reason: 'login'), isFalse);
  });

  test('delivers an accepted restart on the next event turn', () async {
    final delivered = Completer<String>();
    service.registerHandler((reason) async {
      delivered.complete(reason);
    });

    expect(service.request(reason: 'login'), isTrue);
    expect(delivered.isCompleted, isFalse);
    expect(await delivered.future, 'login');
    await pumpEventQueue();
  });

  test('coalesces requests queued before the restart handler runs', () async {
    final delivered = Completer<String>();
    var callCount = 0;
    service.registerHandler((reason) async {
      callCount += 1;
      delivered.complete(reason);
    });

    expect(service.request(reason: 'login'), isTrue);
    expect(service.request(reason: 'account switch'), isTrue);

    expect(await delivered.future, 'login, account switch');
    expect(callCount, 1);
    await pumpEventQueue();
  });

  test('drains a request accepted while a restart is in progress', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondDelivered = Completer<String>();
    final reasons = <String>[];
    service.registerHandler((reason) async {
      reasons.add(reason);
      if (reasons.length == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      } else {
        secondDelivered.complete(reason);
      }
    });

    expect(service.request(reason: 'login'), isTrue);
    await firstStarted.future;

    expect(service.request(reason: 'reconcile complete'), isTrue);
    releaseFirst.complete();

    expect(await secondDelivered.future, 'reconcile complete');
    expect(reasons, ['login', 'reconcile complete']);
    await pumpEventQueue();
  });

  test('does not call a host that unregisters before the event turn', () async {
    var called = false;
    service.registerHandler((reason) async {
      called = true;
    });

    expect(service.request(reason: 'logout'), isTrue);
    service.unregisterHandler();
    await pumpEventQueue();

    expect(called, isFalse);
  });
}
