import 'dart:io' show Platform;

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/status.dart';
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

  Node? _node;
  NodeRpcClient? _rpc;

  /// Initialize flutter_rust_bridge and load the dynamic library.
  /// Call once at app startup (before runApp).
  Future<void> init() async {
    if (_initialized) return;
    await RustLib.init(
      externalLibrary: Platform.isIOS
          ? ExternalLibrary.process(iKnowHowToUseIt: true)
          : null,
    );
    _initialized = true;
  }

  /// Build and start the Rust node, then expose an RPC client.
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> startNode({int? httpPort}) async {
    if (!_initialized) {
      await init();
    }
    if (_nodeRunning) return;

    final builder = NodeBuilder();
    if (httpPort != null) {
      builder.httpServer(port: httpPort);
    }

    _node = builder.build();
    _rpc = _node!.rpc();

    // Run the node in a background thread.
    _node!.runForeverInNewThread();
    _nodeRunning = true;
  }

  /// Obtain the RPC client for ad-hoc calls.
  NodeRpcClient? get rpc => _rpc;

  /// Convenience helper to fetch node status via RPC.
  Future<RpcStatusResp?> getStatus() async {
    final r = _rpc;
    if (r == null) return null;
    return r.status();
  }

  /// Dispose bridge resources when the app is exiting.
  void dispose() {
    RustLib.dispose();
    _initialized = false;
    _nodeRunning = false;
    _node = null;
    _rpc = null;
  }
}
