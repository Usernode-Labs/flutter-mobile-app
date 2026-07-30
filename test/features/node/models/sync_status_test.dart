import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/node/models/sync_status.dart';

void main() {
  group('factories set state/label/progress', () {
    test('connecting', () {
      final s = SyncStatus.connecting();
      expect(s.state, NodeConnectionState.connecting);
      expect(s.isConnecting, isTrue);
      expect(s.progress, 0.0);
      expect(s.connectedPeers, 0);
    });

    test('synced is fully progressed', () {
      final s = SyncStatus.synced(
          localHeight: 100, networkHeight: 100, connectedPeers: 3);
      expect(s.isSynced, isTrue);
      expect(s.progress, 1.0);
      expect(s.label, 'Synced');
    });

    test('error uses message or default', () {
      expect(SyncStatus.error().label, 'Error');
      expect(SyncStatus.error(message: 'boom').label, 'boom');
      expect(SyncStatus.error().hasError, isTrue);
    });

    test('syncing computes progress from applied/target and labels percent',
        () {
      final s = SyncStatus.syncing(
        localHeight: 50,
        networkHeight: 100,
        connectedPeers: 2,
        appliedBlocks: BigInt.from(25),
        targetBlocks: BigInt.from(100),
      );
      expect(s.isSyncing, isTrue);
      expect(s.progress, closeTo(0.25, 1e-9));
      expect(s.label, 'Syncing (25.0%)');
    });

    test('syncing without apply progress is 0 and clamps over-progress', () {
      expect(
        SyncStatus.syncing(localHeight: 1, networkHeight: 2, connectedPeers: 1)
            .progress,
        0.0,
      );
      final over = SyncStatus.syncing(
        localHeight: 1,
        networkHeight: 2,
        connectedPeers: 1,
        appliedBlocks: BigInt.from(200),
        targetBlocks: BigInt.from(100),
      );
      expect(over.progress, 1.0);
    });
  });

  group('blocksRemaining', () {
    test('difference when local < network', () {
      final s = SyncStatus.syncing(
          localHeight: 30, networkHeight: 100, connectedPeers: 1);
      expect(s.blocksRemaining, 70);
    });
    test('null when synced/unknown', () {
      expect(SyncStatus.connecting().blocksRemaining, isNull);
      expect(
        SyncStatus.synced(
                localHeight: 100, networkHeight: 100, connectedPeers: 1)
            .blocksRemaining,
        isNull,
      );
    });
  });

  test('equality and hashCode by value', () {
    final a = SyncStatus.synced(
        localHeight: 10, networkHeight: 10, connectedPeers: 2);
    final b = SyncStatus.synced(
        localHeight: 10, networkHeight: 10, connectedPeers: 2);
    final c = SyncStatus.synced(
        localHeight: 11, networkHeight: 11, connectedPeers: 2);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });

  test('toString includes state and percent', () {
    expect(SyncStatus.connecting().toString(), contains('progress: 0.0%'));
  });
}
