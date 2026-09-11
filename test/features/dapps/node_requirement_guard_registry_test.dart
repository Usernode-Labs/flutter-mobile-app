import 'dart:async';

import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';
import 'package:crypto_mobile_app/features/dapps/node_requirement_guard_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit release is exact, scope-bound, realm-bound and idempotent',
      () async {
    final lease = _FakeLease();
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'guard-a',
    );
    final guardId = await registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-a',
      acquireLease: () async => lease,
    );

    expect(guardId, 'guard-a');
    expect(registry.activeCount, 1);
    expect(
      await registry.release(
        guardId: guardId!,
        scope: 'settings',
        realmMarker: 'realm-a',
      ),
      isFalse,
    );
    expect(
      await registry.release(
        guardId: guardId,
        scope: 'wallet',
        realmMarker: 'realm-b',
      ),
      isFalse,
    );
    expect(lease.releaseCalls, 0);

    expect(
      await registry.release(
        guardId: guardId,
        scope: 'wallet',
        realmMarker: 'realm-a',
      ),
      isTrue,
    );
    expect(
      await registry.release(
        guardId: guardId,
        scope: 'wallet',
        realmMarker: 'realm-a',
      ),
      isFalse,
    );
    expect(lease.releaseCalls, 1);
    expect(registry.activeCount, 0);
  });

  test('replacement document releases only retired-realm guards', () async {
    final oldLease = _FakeLease();
    final currentLease = _FakeLease();
    var nextId = 0;
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'guard-${nextId++}',
    );
    await registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-old',
      acquireLease: () async => oldLease,
    );
    await registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-current',
      acquireLease: () async => currentLease,
    );

    await registry.retainOnlyRealm('realm-current');

    expect(oldLease.releaseCalls, 1);
    expect(currentLease.releaseCalls, 0);
    expect(registry.activeCount, 1);
  });

  test('navigation racing acquisition cannot publish a leaked guard', () async {
    final acquired = Completer<SessionNodeAwakeLease>();
    final lease = _FakeLease();
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'never-published',
    );
    final acquiring = registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-old',
      acquireLease: () => acquired.future,
    );

    await registry.retainOnlyRealm('realm-new');
    acquired.complete(lease);

    expect(await acquiring, isNull);
    expect(lease.releaseCalls, 1);
    expect(registry.activeCount, 0);
  });

  test('retired realm cannot acquire after the replacement becomes active',
      () async {
    final lease = _FakeLease();
    var acquireCalls = 0;
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'never-published',
    );

    await registry.retainOnlyRealm('realm-new');
    final guardId = await registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-old',
      acquireLease: () async {
        acquireCalls++;
        return lease;
      },
    );

    expect(guardId, isNull);
    expect(acquireCalls, 0);
    expect(lease.releaseCalls, 0);
  });

  test('release-all blocks acquisition until a document realm is active',
      () async {
    final blockedLease = _FakeLease();
    final activeLease = _FakeLease();
    var nextId = 0;
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'guard-${nextId++}',
    );

    await registry.releaseAll();
    expect(
      await registry.acquire(
        scope: 'wallet',
        realmMarker: 'realm-a',
        acquireLease: () async => blockedLease,
      ),
      isNull,
    );
    await registry.retainOnlyRealm('realm-a');
    expect(
      await registry.acquire(
        scope: 'wallet',
        realmMarker: 'realm-a',
        acquireLease: () async => activeLease,
      ),
      'guard-0',
    );
    expect(blockedLease.releaseCalls, 0);
  });

  test('WebView disposal drains guards and late acquisitions', () async {
    final liveLease = _FakeLease();
    final lateLease = _FakeLease();
    final acquired = Completer<SessionNodeAwakeLease>();
    var nextId = 0;
    final registry = NodeRequirementGuardRegistry(
      guardIdFactory: () => 'guard-${nextId++}',
    );
    await registry.acquire(
      scope: 'wallet',
      realmMarker: 'realm-a',
      acquireLease: () async => liveLease,
    );
    final late = registry.acquire(
      scope: 'settings',
      realmMarker: 'realm-a',
      acquireLease: () => acquired.future,
    );

    await registry.dispose();
    acquired.complete(lateLease);

    expect(await late, isNull);
    expect(liveLease.releaseCalls, 1);
    expect(lateLease.releaseCalls, 1);
    expect(registry.activeCount, 0);
  });
}

final class _FakeLease implements SessionNodeAwakeLease {
  @override
  SessionNodeAwakeReason get reason => SessionNodeAwakeReason.bridgeRequirement;

  int releaseCalls = 0;

  @override
  Future<void> release() async {
    releaseCalls++;
  }
}
