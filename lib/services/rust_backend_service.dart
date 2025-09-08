import 'dart:io' show Platform;
import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
import 'package:crypto_mobile_app/services/accounts_repository.dart';
import 'package:crypto_mobile_app/utils/logger.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:crypto_mobile_app/src/rust/frb_generated.dart';
import 'package:crypto_mobile_app/src/rust/node.dart';
import 'package:crypto_mobile_app/src/rust/node/builder.dart';
import 'package:crypto_mobile_app/src/rust/rpc.dart';

/// A small façade around flutter_rust_bridge generated APIs.
/// Centralizes initialization and access to the Rust node / RPC.
class RustBackendService {
  RustBackendService._();
  static RustBackendService? _instance;
  static RustBackendService get instance =>
      _instance ??= RustBackendService._();

  bool _initialized = false;
  bool _nodeRunning = false;
  String? _instanceId;

  Node? _node;
  NodeRpcClient? _rpc;
  bool get isRunning => _nodeRunning;
  String? get instanceId => _instanceId;
  void setInstanceId(String id) {
    _instanceId = id;
  }

  /// Initialize flutter_rust_bridge and load the dynamic library.
  /// Call once at app startup (before runApp).
  Future<void> init() async {
    if (_initialized) return;
    Log.i('RUST', 'Init FRB');
    await RustLib.init(
      externalLibrary: Platform.isIOS
          ? ExternalLibrary.process(iKnowHowToUseIt: true)
          : null,
    );
    _initialized = true;
    Log.i('RUST', 'Init complete');
  }

  /// Build and start the Rust node, then expose an RPC client.
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> startNode({int? httpPort}) async {
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) return;
    Log.i('RUST', 'Starting node${httpPort != null ? ' on $httpPort' : ''}');

    final builder = NodeBuilder();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    _node = builder.build();
    _rpc = _node!.rpc();

    // Run the node in a background thread.
    _node!.runForeverInNewThread();
    _nodeRunning = true;
    Log.i('RUST', 'Node started');
  }

  Future<void> stopNode() async {
    if (!_initialized && !_nodeRunning) return;
    // Currently frb-generated API does not expose a graceful shutdown; dispose bridge.
    Log.w('RUST', 'Stopping node (dropping references; FRB stays initialized)');
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }

  /// Start node if there is an active account; otherwise do nothing.
  Future<bool> startForActiveAccount() async {
    Log.d('RUST', 'startForActiveAccount begin');
    final repo = await AccountsRepository.create();
    final hasAny = await repo.hasAny();
    if (!hasAny) return false;
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) return true;
    await startNode();
    Log.d('RUST', 'startForActiveAccount done');
    return true;
  }

  /// Restart node using current active account context.
  Future<void> restartForActiveAccount() async {
    Log.i('RUST', 'Restarting node for active account');
    await stopNode();
    await startForActiveAccount();
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus() async {
    Log.d('RUST', 'getStatus called');
    final r = _rpc;
    if (r == null) return null;
    final status = await r.status();
    // Log the response for debugging purposes as JSON.
    try {
      if (status != null) {
        final peers = status.peers
            .map((p) => {
                  'address': p.address,
                  'connectingDetails': p.connectingDetails,
                  'connectionStatus': (() {
                    try {
                      final dynamic cs = p.connectionStatus;
                      return (cs as dynamic).name ?? cs.toString().split('.').last;
                    } catch (_) {
                      return p.connectionStatus.toString();
                    }
                  })(),
                  'incoming': p.incoming,
                  'peerId': p.peerId.toString(),
                  'time': p.time.toString(),
                })
            .toList();
        final json = jsonEncode({'peers': peers});
        Log.d('RUST', 'getStatus response: $json');
      }
    } catch (e, st) {
      Log.w('RUST', 'Failed to encode getStatus to JSON: $e\n$st');
    }
    Log.d('RUST', 'getStatus ok');
    return status;
  }

  /// Dispose bridge resources when the app is exiting.
  void dispose() {
    // Keep FRB initialized for app lifetime to avoid double-init errors.
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }
}
