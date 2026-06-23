import 'package:crypto_mobile_app/core/providers/top_status_node_status_provider.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/node/models/sync_status.dart';
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
}
