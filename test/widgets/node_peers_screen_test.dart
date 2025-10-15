import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/features/node/presentation/screens/node_peers_screen.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';
import 'package:crypto_mobile_app/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('NodePeersScreen renders a list of peers', (tester) async {
    final peers = <RpcPeerInfo>[
      _FakeRpcPeerInfo(
        peerId: _FakePeerId('p1'),
        address: '/ip4/127.0.0.1/tcp/7000',
        connectionStatus: PeerConnectionStatus.connected,
        connectingDetails: '',
        incoming: false,
        time: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      ),
      _FakeRpcPeerInfo(
        peerId: _FakePeerId('p2'),
        address: null,
        connectionStatus: PeerConnectionStatus.connecting,
        connectingDetails: '/ip4/10.0.0.1/tcp/7001',
        incoming: true,
        time: BigInt.from(DateTime.now().millisecondsSinceEpoch),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: NodePeersScreen(peers: peers),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Node Peers'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(2));
  });
}

// Test-only fakes for FRB abstract interfaces
class _FakePeerId implements PeerId {
  final String _s;
  _FakePeerId(this._s);
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
  }
  @override
  bool get isDisposed => _disposed;
  @override
  String toString() => _s;
}

class _FakeRpcPeerInfo implements RpcPeerInfo {
  _FakeRpcPeerInfo({
    required PeerId peerId,
    required String? address,
    required PeerConnectionStatus connectionStatus,
    required String? connectingDetails,
    required bool incoming,
    required BigInt time,
  })  : _peerId = peerId,
        _address = address,
        _connectionStatus = connectionStatus,
        _connectingDetails = connectingDetails,
        _incoming = incoming,
        _time = time;

  String? _address;
  String? _connectingDetails;
  PeerConnectionStatus _connectionStatus;
  bool _incoming;
  PeerId _peerId;
  BigInt _time;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
  }

  @override
  bool get isDisposed => _disposed;

  @override
  String? get address => _address;
  @override
  set address(String? address) => _address = address;

  @override
  String? get connectingDetails => _connectingDetails;
  @override
  set connectingDetails(String? connectingDetails) =>
      _connectingDetails = connectingDetails;

  @override
  PeerConnectionStatus get connectionStatus => _connectionStatus;
  @override
  set connectionStatus(PeerConnectionStatus connectionStatus) =>
      _connectionStatus = connectionStatus;

  @override
  bool get incoming => _incoming;
  @override
  set incoming(bool incoming) => _incoming = incoming;

  @override
  PeerId get peerId => _peerId;
  @override
  set peerId(PeerId peerId) => _peerId = peerId;

  @override
  BigInt get time => _time;
  @override
  set time(BigInt time) => _time = time;
}
