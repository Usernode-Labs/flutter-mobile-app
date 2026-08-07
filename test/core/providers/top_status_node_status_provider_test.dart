import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection state mapper keeps syncing distinct', () {
    expect(
      topStatusNodeStatusFromConnectionState(NodeConnectionState.synced),
      TopStatusNodeStatus.synced,
    );
    expect(
      topStatusNodeStatusFromConnectionState(NodeConnectionState.connecting),
      TopStatusNodeStatus.connecting,
    );
    expect(
      topStatusNodeStatusFromConnectionState(NodeConnectionState.syncing),
      TopStatusNodeStatus.syncing,
    );
    expect(
      topStatusNodeStatusFromConnectionState(NodeConnectionState.error),
      TopStatusNodeStatus.offline,
    );
    expect(
      topStatusNodeStatusFromConnectionState(null),
      TopStatusNodeStatus.offline,
    );
  });

  test('sync status mapper supports compact icon loading semantics', () {
    expect(
      topStatusNodeStatusFromSyncStatus(
        null,
        nullStatus: TopStatusNodeStatus.connecting,
      ),
      TopStatusNodeStatus.connecting,
    );
    expect(
      topStatusNodeStatusFromSyncStatus(SyncStatus.connecting()),
      TopStatusNodeStatus.connecting,
    );
    expect(
      topStatusNodeStatusFromSyncStatus(
        SyncStatus.syncing(
          localHeight: 4,
          networkHeight: 8,
          connectedPeers: 1,
        ),
      ),
      TopStatusNodeStatus.syncing,
    );
    expect(
      topStatusNodeStatusFromSyncStatus(
        SyncStatus.synced(
          localHeight: 8,
          networkHeight: 8,
          connectedPeers: 1,
        ),
      ),
      TopStatusNodeStatus.synced,
    );
    expect(
      topStatusNodeStatusFromSyncStatus(SyncStatus.error()),
      TopStatusNodeStatus.offline,
    );
  });

  group('topStatusChromeNodeStatusProvider', () {
    ProviderContainer containerWithRawStatus(
      StateProvider<TopStatusNodeStatus> rawStatusProvider,
    ) {
      return ProviderContainer(
        overrides: [
          topStatusChromeSyncingGracePeriodProvider.overrideWithValue(
            const Duration(milliseconds: 20),
          ),
          topStatusChromeRawNodeStatusProvider.overrideWith(
            (ref) => ref.watch(rawStatusProvider),
          ),
        ],
      );
    }

    test('holds synced through a short syncing blip', () async {
      final rawStatusProvider = StateProvider<TopStatusNodeStatus>(
        (ref) => TopStatusNodeStatus.synced,
      );
      final container = containerWithRawStatus(rawStatusProvider);
      addTearDown(container.dispose);

      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.syncing;
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.synced;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );
    });

    test('shows syncing after the grace window', () async {
      final rawStatusProvider = StateProvider<TopStatusNodeStatus>(
        (ref) => TopStatusNodeStatus.synced,
      );
      final container = containerWithRawStatus(rawStatusProvider);
      addTearDown(container.dispose);

      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.syncing;
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.syncing,
      );
    });

    test('offline and connecting bypass smoothing', () {
      final rawStatusProvider = StateProvider<TopStatusNodeStatus>(
        (ref) => TopStatusNodeStatus.synced,
      );
      final container = containerWithRawStatus(rawStatusProvider);
      addTearDown(container.dispose);

      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.synced,
      );

      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.offline;
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.offline,
      );

      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.synced;
      container.read(rawStatusProvider.notifier).state =
          TopStatusNodeStatus.connecting;
      expect(
        container.read(topStatusChromeNodeStatusProvider),
        TopStatusNodeStatus.connecting,
      );
    });
  });
}
