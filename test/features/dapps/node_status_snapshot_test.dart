import 'package:crypto_mobile_app/features/dapps/node_status_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('node status snapshot exposes native diagnostics for Social Vibecoding',
      () {
    expect(
      dappNodeStatusSnapshot(
        status: 'syncing',
        chain: 'testnet',
        localBestHeight: 120,
        localBestTimestampMs: 1770000000000,
        networkBestHeight: 130,
        readyPeers: 4,
        totalPeers: 7,
        syncStalled: true,
        clockDriftMs: 6000,
        walletDataHydrating: true,
      ),
      {
        'status': 'syncing',
        'chain': 'testnet',
        'localBestHeight': 120,
        'localBestTimestampMs': 1770000000000,
        'networkBestHeight': 130,
        'readyPeers': 4,
        'connectedPeers': 4,
        'totalPeers': 7,
        'syncStalled': true,
        'clockDriftMs': 6000,
        'walletDataHydrating': true,
      },
    );
  });
}
