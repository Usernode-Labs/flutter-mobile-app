import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_peers_screen.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/third_party/usernode_p2p/identity.dart';
import 'package:crypto_mobile_app/src/rust/lib.dart';

void main() {
  testWidgets('NodePeersScreen renders a list of peers', (tester) async {
    final peers = [
      RpcPeerInfo(
        peerId: PeerId(field0: U64Array4.init()),
        address: '/ip4/127.0.0.1/tcp/7000',
        connectionStatus: PeerConnectionStatus.connected,
        connectingDetails: '',
        incoming: false,
        time: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      ),
      RpcPeerInfo(
        peerId: PeerId(field0: U64Array4.init()),
        address: null,
        connectionStatus: PeerConnectionStatus.connecting,
        connectingDetails: '/ip4/10.0.0.1/tcp/7001',
        incoming: true,
        time: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      ),
    ];

    await tester.pumpWidget(MaterialApp(home: NodePeersScreen(peers: peers)));
    await tester.pumpAndSettle();

    expect(find.text('Node Peers'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}

