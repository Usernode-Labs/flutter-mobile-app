import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/core/providers/staking_provider.dart';
import 'package:crypto_mobile_app/core/services/staking_preference_store.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/wallet/data/delegation_api.dart';

void main() {
  const store = StakingPreferenceStore(bucket: 'account-a');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await NetworkPrefs.init();
  });

  StakingController controller({
    Future<DelegationStatus> Function(bool delegated)? syncBackend,
    Future<DelegationStatus?> Function()? fetchBackend,
    Future<void> Function()? applyNodeEffects,
    bool Function()? isScopeCurrent,
    bool hydrate = false,
  }) =>
      StakingController(
        store: store,
        syncBackend: syncBackend,
        fetchBackend: fetchBackend,
        applyNodeEffects: applyNodeEffects,
        isScopeCurrent: isScopeCurrent,
        hydrate: hydrate,
      );

  test('bridge snapshot exposes a nullable delegate address', () async {
    final subject = controller();
    addTearDown(subject.dispose);

    expect(subject.state, const StakingState.active());
    expect(subject.state.toBridgeJson(), {
      'delegate': null,
      'delegated_since': null,
    });

    await subject.delegate();

    expect(subject.state.toBridgeJson(), {
      'delegate': kServerDelegateAddress,
      'delegated_since': null,
    });
  });

  test(
    'delegate synchronizes, persists, updates state, and applies effects',
    () async {
      final events = <String>[];
      final subject = controller(
        syncBackend: (delegated) async {
          events.add('sync:$delegated');
          return const DelegationStatus(
            delegated: true,
            delegatedSince: '2026-08-11T10:30:00Z',
          );
        },
        applyNodeEffects: () async => events.add('effects'),
      );
      addTearDown(subject.dispose);

      await subject.delegate();
      await Future<void>.delayed(Duration.zero);

      expect(events, ['sync:true', 'effects']);
      expect(subject.state.isDelegated, isTrue);
      expect(subject.state.delegateAddress, kServerDelegateAddress);
      expect(subject.state.delegatedSince, '2026-08-11T10:30:00Z');
      expect(await store.loadDelegateAddress(), kServerDelegateAddress);
    },
  );

  test('undelegate synchronizes and clears the persisted target', () async {
    final subject = controller();
    addTearDown(subject.dispose);
    await subject.delegate();

    await subject.undelegate();

    expect(subject.state, const StakingState.active());
    expect(await store.loadDelegateAddress(), isNull);
  });

  test('backend failure leaves state and persistence unchanged', () async {
    final subject = controller(
      syncBackend: (_) =>
          Future<DelegationStatus>.error(StateError('backend down')),
    );
    addTearDown(subject.dispose);

    await expectLater(subject.delegate(), throwsStateError);

    expect(subject.state, const StakingState.active());
    expect(await store.loadDelegateAddress(), isNull);
  });

  test('hydrate restores local delegation', () async {
    await store.setDelegateAddress(kServerDelegateAddress);
    final subject = controller(hydrate: true);
    addTearDown(subject.dispose);

    await subject.ready;

    expect(subject.state.isDelegated, isTrue);
  });

  test('backend state reconciles the local preference', () async {
    final subject = controller(
      fetchBackend: () async => const DelegationStatus(
        delegated: true,
        delegatedSince: '2026-08-11T10:30:00Z',
      ),
      hydrate: true,
    );
    addTearDown(subject.dispose);

    await subject.ready;

    expect(subject.state.isDelegated, isTrue);
    expect(subject.state.delegatedSince, '2026-08-11T10:30:00Z');
    expect(await store.loadDelegateAddress(), kServerDelegateAddress);
  });

  test('stale identity scope never publishes state or node effects', () async {
    var current = true;
    final syncStarted = Completer<void>();
    final allowSync = Completer<void>();
    var effects = 0;
    final subject = controller(
      syncBackend: (_) async {
        syncStarted.complete();
        await allowSync.future;
        return const DelegationStatus(delegated: true);
      },
      isScopeCurrent: () => current,
      applyNodeEffects: () async => effects++,
    );
    addTearDown(subject.dispose);

    final delegation = subject.delegate();
    await syncStarted.future;
    current = false;
    allowSync.complete();
    await delegation;

    expect(subject.state, const StakingState.active());
    expect(effects, 0);
    expect(await store.loadDelegateAddress(), kServerDelegateAddress);
  });
}
